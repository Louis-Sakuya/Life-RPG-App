import Foundation
import SwiftData

struct LevelUpEvent: Identifiable, Hashable, Sendable {
    var id = UUID()
    /// 技能升级时为技能名，玩家升级时为 nil
    var skillName: String?
    var level: Int
    var goldReward: Int
}

/// 经济系统的唯一写入口。任何 EXP / Gold 的变动都必须经过这里，
/// 因为只有这里会同时落流水、更新计数器与刷新当日聚合。
@MainActor
final class RewardService {
    private let context: ModelContext
    private let config: GameConfig
    private let calendar: GameCalendar
    private let records: RecordRepository
    private let skills: SkillRepository

    /// 本次会话中产生的升级事件，由 UI 消费后清空
    private(set) var pendingLevelUps: [LevelUpEvent] = []

    init(context: ModelContext, config: GameConfig, calendar: GameCalendar) {
        self.context = context
        self.config = config
        self.calendar = calendar
        self.records = RecordRepository(context: context)
        self.skills = SkillRepository(context: context)
    }

    // MARK: - 发放

    @discardableResult
    func grant(
        _ result: RewardResult,
        to player: Player,
        source: RewardSourceKind,
        sourceID: UUID? = nil,
        sourceRuleID: String? = nil,
        title: String,
        on day: GameDay
    ) -> RewardTransaction {
        let transaction = RewardTransaction(
            sourceKind: source,
            sourceID: sourceID,
            sourceRuleID: sourceRuleID,
            sourceTitle: title,
            expDelta: result.exp,
            goldDelta: result.gold,
            skillEXP: result.skillEXP,
            day: day,
            breakdown: result.breakdownText
        )
        records.insert(transaction)
        apply(transaction, to: player, sign: 1)
        return transaction
    }

    /// 直接发放固定数值，用于成就、挑战、升级这类不走公式的奖励
    @discardableResult
    func grantFlat(
        exp: Int,
        gold: Int,
        to player: Player,
        source: RewardSourceKind,
        sourceID: UUID? = nil,
        sourceRuleID: String? = nil,
        title: String,
        on day: GameDay
    ) -> RewardTransaction? {
        guard exp != 0 || gold != 0 else { return nil }
        let transaction = RewardTransaction(
            sourceKind: source,
            sourceID: sourceID,
            sourceRuleID: sourceRuleID,
            sourceTitle: title,
            expDelta: exp,
            goldDelta: gold,
            day: day,
            breakdown: "\(exp) EXP / \(gold) G"
        )
        records.insert(transaction)
        apply(transaction, to: player, sign: 1)
        return transaction
    }

    // MARK: - 回滚

    /// 按流水记录的数值原样反向扣除。刻意不重算公式：
    /// 配置随时可能被调整，重算会让玩家的历史收益凭空变化。
    func revert(_ transaction: RewardTransaction, for player: Player) {
        guard !transaction.isReverted else { return }
        apply(transaction, to: player, sign: -1)
        transaction.isReverted = true
        transaction.revertedAt = Date()
    }

    func revertAll(sourceID: UUID, for player: Player) {
        for transaction in records.activeTransactions(sourceID: sourceID) {
            revert(transaction, for: player)
        }
    }

    /// 只回滚某来源在指定日的流水。习惯每天都会产生一笔，撤销打卡时只能动当天那笔。
    func revertAll(sourceID: UUID, on day: GameDay, for player: Player) {
        for transaction in records.activeTransactions(sourceID: sourceID, on: day) {
            revert(transaction, for: player)
        }
    }

    // MARK: - 升级事件

    func consumeLevelUps() -> [LevelUpEvent] {
        let events = pendingLevelUps
        pendingLevelUps.removeAll()
        return events
    }

    // MARK: - 内部

    private func apply(_ transaction: RewardTransaction, to player: Player, sign: Int) {
        let expDelta = transaction.expDelta * sign
        let goldDelta = transaction.goldDelta * sign

        let previousEXP = player.totalEXP
        player.totalEXP = max(0, player.totalEXP + expDelta)
        player.gold = max(0, player.gold + goldDelta)

        if sign > 0 {
            player.totalEXPEarned += max(0, expDelta)
            player.totalGoldEarned += max(0, goldDelta)
        } else {
            player.totalEXPEarned = max(0, player.totalEXPEarned + expDelta)
            player.totalGoldEarned = max(0, player.totalGoldEarned + goldDelta)
        }

        applySkillEXP(transaction.skillEXP, sign: sign)
        updateDailyRecord(transaction, sign: sign)

        // 升级奖励只在正向发放时结算，回滚时不再倒扣升级金币，
        // 因为那笔金币本身也有独立流水，重复处理会双倍扣除。
        if sign > 0 {
            settlePlayerLevelUps(player: player, from: previousEXP, to: player.totalEXP, on: transaction.day)
        }
    }

    private func applySkillEXP(_ distribution: [UUID: Int], sign: Int) {
        guard !distribution.isEmpty else { return }
        let lookup = skills.skills(ids: Array(distribution.keys))
        for (skillID, amount) in distribution {
            guard let skill = lookup[skillID] else { continue }
            let before = skill.totalEXP
            skill.totalEXP = max(0, skill.totalEXP + amount * sign)
            guard sign > 0 else { continue }
            for level in config.skillCurve.levelsGained(from: before, to: skill.totalEXP) {
                pendingLevelUps.append(LevelUpEvent(skillName: skill.name, level: level, goldReward: 0))
            }
        }
    }

    private func updateDailyRecord(_ transaction: RewardTransaction, sign: Int) {
        // 消费不计入"今日获得"。否则玩家买一个主题，首页的今日金币就会倒退，
        // 而那个数字表达的是产出而非余额。
        guard transaction.sourceKind != .purchase else { return }
        let record = records.ensureRecord(on: transaction.day)
        record.expEarned = max(0, record.expEarned + transaction.expDelta * sign)
        record.goldEarned = max(0, record.goldEarned + transaction.goldDelta * sign)
        record.updatedAt = Date()
    }

    private func settlePlayerLevelUps(player: Player, from previousEXP: Int, to newEXP: Int, on day: GameDay) {
        let curve = config.playerCurve
        let gained = curve.levelsGained(from: previousEXP, to: newEXP)
        guard !gained.isEmpty else { return }

        let engine = RewardEngine(config: config)
        // 只对从未奖励过的等级发放。等级会因为撤销任务而回落，
        // 不设这道水位线的话反复完成 / 撤销就能无限刷金币。
        for level in gained where level > player.highestLevelRewarded {
            player.highestLevelRewarded = level
            let gold = engine.levelUpGold(forLevel: level)
            pendingLevelUps.append(LevelUpEvent(skillName: nil, level: level, goldReward: gold))

            let bonus = RewardTransaction(
                sourceKind: .levelUp,
                sourceRuleID: "level_\(level)",
                sourceTitle: "升级到 Lv\(level)",
                expDelta: 0,
                goldDelta: gold,
                day: day,
                breakdown: "升级奖励 \(gold) G"
            )
            records.insert(bonus)
            player.gold += gold
            player.totalGoldEarned += gold

            let record = records.ensureRecord(on: day)
            record.goldEarned += gold
        }
    }
}
