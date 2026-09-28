import Foundation
import SwiftData

/// 首次启动的数据播种。技能与习惯不再预置，由初始化流程让玩家自己选；
/// 内置挑战仍然每次启动对账，这样配置表新增后老存档也能拿到。
@MainActor
struct SeedService {
    private let context: ModelContext
    private let config: GameConfig
    private let calendar: GameCalendar

    init(context: ModelContext, config: GameConfig, calendar: GameCalendar) {
        self.context = context
        self.config = config
        self.calendar = calendar
    }

    func bootstrap() {
        let players = PlayerRepository(context: context)
        _ = players.currentPlayer()
        _ = players.settings()

        backfillSkillCatalogMetadata()
        migrateOnboardingIfNeeded()
        migrateTutorialIfNeeded()
        migrateSkillSlotsIfNeeded()
        syncBuiltInChallenges()
    }

    /// 老存档里的技能没有亲和度。按名字对上目录后补上，自定义技能保持不动。
    private func backfillSkillCatalogMetadata() {
        let repository = SkillRepository(context: context)
        for skill in repository.allSkills(includeArchived: true) {
            if !skill.catalogID.isEmpty, skill.affinities.isEmpty,
               let preset = config.skillCatalog.preset(id: skill.catalogID) {
                skill.categoryTokens = preset.categories
                skill.affinities = preset.parsedAffinities
                continue
            }
            guard skill.catalogID.isEmpty, skill.affinities.isEmpty else { continue }
            guard let preset = config.skillCatalog.preset(matchingName: skill.name) else { continue }
            skill.catalogID = preset.id
            if skill.categoryTokens.isEmpty {
                skill.categoryTokens = preset.categories
            }
            skill.affinities = preset.parsedAffinities
        }
    }

    /// 升级前已经在用的存档跳过初始化流程，避免老用户被重新拉去起名选技能。
    private func migrateOnboardingIfNeeded() {
        let players = PlayerRepository(context: context)
        let settings = players.settings()
        guard !settings.hasCompletedOnboarding else { return }

        let player = players.currentPlayer()
        let hasSkills = !SkillRepository(context: context).allSkills(includeArchived: true).isEmpty
        let hasHabits = !HabitRepository(context: context).allHabits(includeArchived: true).isEmpty
        let hasProgress =
            player.lastActiveDayValue > 0
            || player.totalEXP > 0
            || player.totalQuestsCompleted > 0
            || player.totalHabitCheckIns > 0
            || player.nickname != Player.defaultNickname

        if hasSkills || hasHabits || hasProgress {
            settings.hasCompletedOnboarding = true
        }
    }

    /// 升级前已经完成初始化的存档跳过新手引导，避免老玩家被强制再走一遍。
    private func migrateTutorialIfNeeded() {
        let settings = PlayerRepository(context: context).settings()
        guard !settings.hasCompletedTutorial else { return }
        guard settings.tutorialStepRaw.isEmpty else { return }
        if settings.hasCompletedOnboarding {
            settings.hasCompletedTutorial = true
        }
    }

    /// 老存档可能已经学了超过初始栏位的技能，栏位至少要装得下现有技能。
    private func migrateSkillSlotsIfNeeded() {
        let player = PlayerRepository(context: context).currentPlayer()
        let initial = max(1, config.balance.initialSkillSlots)
        if player.skillSlotCap < initial {
            player.skillSlotCap = initial
        }
        let learned = SkillRepository(context: context).allSkills().count
        if learned > player.skillSlotCap {
            player.skillSlotCap = learned
        }
    }

    /// 内置挑战每次启动都对账一次：新增规则会插入，已有规则会同步条件，
    /// 这样改 JSON 里的技能名或阈值后，老存档也能跟上。
    private func syncBuiltInChallenges() {
        let repository = ProgressionRepository(context: context)
        for rule in config.unlocks.rules(of: .challenge) {
            if let existing = repository.challenge(ruleID: rule.id) {
                apply(rule, to: existing)
                continue
            }
            guard let challenge = Challenge.fromRule(rule) else { continue }
            repository.insert(challenge)
        }
    }

    private func apply(_ rule: UnlockRule, to challenge: Challenge) {
        guard let condition = rule.conditions.first else { return }
        challenge.title = rule.name
        challenge.detail = rule.detail
        challenge.iconName = rule.icon
        challenge.metricKey = condition.metric
        challenge.metricParam = condition.param
        challenge.comparator = condition.comparator
        challenge.threshold = condition.threshold
        challenge.rewardEXP = rule.reward.exp
        challenge.rewardGold = rule.reward.gold
        challenge.rewardTitleID = rule.reward.titleID
    }
}
