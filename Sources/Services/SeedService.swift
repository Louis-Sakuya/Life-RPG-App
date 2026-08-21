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

    /// 内置挑战每次启动都对账一次，这样在 `unlock_rules.json` 里新增挑战后，
    /// 老用户升级应用也能拿到，而不需要写迁移代码。
    private func syncBuiltInChallenges() {
        let repository = ProgressionRepository(context: context)
        for rule in config.unlocks.rules(of: .challenge) {
            guard repository.challenge(ruleID: rule.id) == nil else { continue }
            guard let challenge = Challenge.fromRule(rule) else { continue }
            repository.insert(challenge)
        }
    }
}
