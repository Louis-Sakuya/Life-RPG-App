import Foundation
import SwiftData

/// 驱动解锁引擎并落地它的产出：记录解锁、发放奖励、标记挑战完成。
@MainActor
final class UnlockService {
    /// 解锁奖励本身会涨经验，可能连锁触发等级类成就，因此需要反复评估直到稳定。
    /// 上限用于防御规则表里出现互相触发的环。
    private static let maxSettleRounds = 5

    private let context: ModelContext
    private let config: GameConfig
    private let calendar: GameCalendar
    private let metrics: MetricsService
    private let progression: ProgressionRepository
    private let rewards: RewardService

    init(
        context: ModelContext,
        config: GameConfig,
        calendar: GameCalendar,
        metrics: MetricsService,
        rewards: RewardService
    ) {
        self.context = context
        self.config = config
        self.calendar = calendar
        self.metrics = metrics
        self.progression = ProgressionRepository(context: context)
        self.rewards = rewards
    }

    /// 跑一轮评估，返回本次新解锁的规则，供界面弹出庆祝
    @discardableResult
    func evaluate(player: Player) -> [UnlockRule] {
        var allNew: [UnlockRule] = []
        let today = calendar.today
        // 本轮内解锁的记录还没保存，不能只依赖查询结果，否则同一条规则可能被重复解锁
        var unlockedIDs = progression.unlockedRuleIDs()

        for _ in 0..<Self.maxSettleRounds {
            let snapshot = metrics.snapshot(player: player)
            let newlyUnlocked = UnlockEngine.evaluate(
                snapshot: snapshot,
                rules: candidateRules(),
                unlockedIDs: unlockedIDs
            )
            guard !newlyUnlocked.isEmpty else { break }

            for rule in newlyUnlocked {
                apply(rule, to: player, on: today)
                unlockedIDs.insert(rule.id)
                allNew.append(rule)
            }
        }

        return allNew
    }

    /// 挑战的实时进度，用于挑战列表的进度条
    func challengeProgress(player: Player) -> [(challenge: Challenge, progress: Double, text: String?)] {
        let snapshot = metrics.snapshot(player: player)
        return progression.allChallenges().map { challenge in
            let rule = challenge.asRule
            return (
                challenge,
                UnlockEngine.progress(of: rule, snapshot: snapshot),
                UnlockEngine.progressText(of: rule, snapshot: snapshot)
            )
        }
    }

    /// 成就与称号的完成进度
    func ruleProgress(player: Player, kind: UnlockKind) -> [(rule: UnlockRule, progress: Double, text: String?, isUnlocked: Bool)] {
        let snapshot = metrics.snapshot(player: player)
        let unlockedIDs = progression.unlockedRuleIDs()
        return config.unlocks.rules(of: kind).map { rule in
            (
                rule,
                UnlockEngine.progress(of: rule, snapshot: snapshot),
                UnlockEngine.progressText(of: rule, snapshot: snapshot),
                unlockedIDs.contains(rule.id)
            )
        }
    }

    func unlockedTitles() -> [UnlockRule] {
        let unlockedIDs = progression.unlockedRuleIDs()
        return config.unlocks.rules(of: .title).filter { unlockedIDs.contains($0.id) }
    }

    // MARK: - 内部

    /// 内置成就与称号来自 JSON，挑战来自数据库（内置挑战已在播种时对账），
    /// 两者统一转成 `UnlockRule` 后走完全相同的评估路径。
    private func candidateRules() -> [UnlockRule] {
        var rules = config.unlocks.rules(of: .achievement)
        rules.append(contentsOf: config.unlocks.rules(of: .title))
        rules.append(contentsOf: progression.allChallenges().filter { !$0.isCompleted }.map(\.asRule))
        return rules
    }

    private func apply(_ rule: UnlockRule, to player: Player, on day: GameDay) {
        progression.record(ruleID: rule.id, kind: rule.kind, day: day)

        if rule.kind == .challenge {
            let challenge = progression.challenge(ruleID: rule.id)
                ?? progression.allChallenges().first { $0.id.uuidString == rule.id }
            challenge?.isCompleted = true
            challenge?.completedDay = day
        }

        if !rule.reward.isEmpty {
            rewards.grantFlat(
                exp: rule.reward.exp,
                gold: rule.reward.gold,
                to: player,
                source: rule.kind == .challenge ? .challenge : .achievement,
                sourceRuleID: rule.id,
                title: rule.name,
                on: day
            )
        }

        // 称号奖励只是"获得"，是否佩戴由玩家决定；但玩家还没有任何称号时自动戴上，
        // 否则第一个称号需要额外一次手动操作才能看到效果。
        if let titleID = rule.reward.titleID, player.currentTitleID == nil {
            player.currentTitleID = titleID
        }
        if rule.kind == .title, player.currentTitleID == nil {
            player.currentTitleID = rule.id
        }
    }
}
