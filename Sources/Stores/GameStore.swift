import Foundation
import Observation
import SwiftData

/// 界面唯一的门面。视图不直接接触 Repository 或 Service，
/// 这样"完成任务"这种牵动四五处副作用的操作只有一条调用路径。
@MainActor
@Observable
final class GameStore {
    let container: AppContainer

    private(set) var player: Player
    private(set) var settings: AppSettings
    private(set) var today: GameDay

    private(set) var todayQuests: [Quest] = []
    private(set) var todayCompletedQuests: [Quest] = []
    private(set) var overdueQuests: [Quest] = []
    /// 开始日已过、但截止日期还没到的长期委托，仍然挂在今日任务栏上
    private(set) var spanningQuests: [Quest] = []
    private(set) var habits: [Habit] = []
    private(set) var skills: [Skill] = []
    private(set) var todayRecord: DailyRecord?
    private(set) var palette: ThemePalette = .default
    /// 当前界面语言。设置页切换后 SwiftUI 用 `.id` 重建整棵界面。
    private(set) var languageCode: String = AppLanguage.system.rawValue
    /// 还没走完首次冒险者设定时，主界面让位给初始化流程。
    private(set) var needsOnboarding = true

    /// 待选择的玩家升级额外奖励。金币已经发放，这里只处理属性点或技能栏位。
    var pendingLevelUpChoices: [LevelUpEvent] = []
    /// 刚选了技能栏位时，先把“现在学习 / 稍后”留在界面上。
    var skillSlotFollowUp: LevelUpEvent?
    var pendingLevelUps: [LevelUpEvent] = []
    var pendingUnlocks: [UnlockRule] = []
    var pendingFortunes: [FortuneEvent] = []

    private var hasBootstrapped = false

    init(container: AppContainer) {
        self.container = container
        let repository = PlayerRepository(context: container.context)
        self.player = repository.currentPlayer()
        self.settings = repository.settings()
        self.today = container.calendar.today
        L10n.bootstrap()
        applyLanguage(settings.language)
        needsOnboarding = !settings.hasCompletedOnboarding
    }

    // MARK: - 生命周期

    func bootstrap() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        container.bootstrap()
        reloadIdentities()
        if needsOnboarding {
            refresh()
            save()
        } else {
            runDayCycle()
        }
    }

    /// 回到前台时调用。跨过午夜的场景就是靠这里被捕捉到的。
    func onForeground() {
        guard !needsOnboarding else { return }
        runDayCycle()
        // 通知采用全量重建，回到前台时重排一次即可覆盖"任务改期""习惯删除"等所有变化
        syncNotifications()
    }

    private func runDayCycle() {
        today = container.calendar.today
        container.dayCycle.runIfNeeded(player: player, settings: settings)
        evaluateUnlocks()
        refresh()
        save()
    }

    // MARK: - 刷新

    func refresh() {
        today = container.calendar.today
        let questRepo = QuestRepository(context: container.context)
        let habitRepo = HabitRepository(context: container.context)
        let skillRepo = SkillRepository(context: container.context)
        let recordRepo = RecordRepository(context: container.context)

        let playerRepo = PlayerRepository(context: container.context)
        player = playerRepo.currentPlayer()
        settings = playerRepo.settings()

        todayQuests = questRepo.quests(on: today)
        todayCompletedQuests = questRepo.questsCompleted(on: today)
        let unfinished = questRepo.unfinishedQuests(before: today)
        overdueQuests = unfinished.filter { quest in
            if let dueAt = quest.dueAt {
                return container.calendar.gameDay(for: dueAt) < today
            }
            return true
        }
        spanningQuests = unfinished.filter { quest in
            guard let dueAt = quest.dueAt else { return false }
            return container.calendar.gameDay(for: dueAt) >= today
        }
        habits = habitRepo.allHabits()
        skills = skillRepo.allSkills()
        todayRecord = recordRepo.record(on: today)
        palette = container.shop.palette(for: player)

        collectLevelUps()
        collectFortunes()
    }

    func save() {
        container.save()
    }

    // MARK: - 派生状态

    var levelProgress: LevelProgress {
        container.config.playerCurve.progress(totalEXP: player.totalEXP)
    }

    var mainQuests: [Quest] {
        todayQuests.filter { $0.kind != .side }
    }

    var sideQuests: [Quest] {
        todayQuests.filter { $0.kind == .side }
    }

    /// 工会任务栏上的主线：今天的主线 / 重复实例，以及仍在截止日期内的跨日委托。
    /// 当天完成的任务留在栏上划掉并沉底，不从列表里拿掉。
    var guildMainQuests: [Quest] {
        mergedBoard(
            primary: mainQuests,
            extra: spanningQuests.filter { $0.kind != .side },
            completedToday: todayCompletedQuests.filter { $0.kind != .side }
        )
    }

    var guildSideQuests: [Quest] {
        mergedBoard(
            primary: sideQuests,
            extra: spanningQuests.filter { $0.kind == .side },
            completedToday: todayCompletedQuests.filter { $0.kind == .side }
        )
    }

    private func mergedBoard(primary: [Quest], extra: [Quest], completedToday: [Quest]) -> [Quest] {
        var seen = Set<UUID>()
        var result: [Quest] = []
        for quest in primary + extra + completedToday {
            guard seen.insert(quest.id).inserted else { continue }
            result.append(quest)
        }
        return result.sorted(by: Quest.boardOrder)
    }

    var todayEXP: Int { todayRecord?.expEarned ?? 0 }
    var todayGold: Int { todayRecord?.goldEarned ?? 0 }
    var todayCompletionRate: Double { todayRecord?.completionRate ?? 0 }

    var streakMultiplier: Double {
        StreakEngine.multiplier(forDays: player.loginStreakCurrent, tiers: container.config.balance.streakTiers)
    }

    var nextStreakTier: BalanceConfig.StreakTier? {
        StreakEngine.nextTier(forDays: player.loginStreakCurrent, tiers: container.config.balance.streakTiers)
    }

    var locale: Locale { L10n.locale }

    var currentTitleName: String? {
        guard let id = player.currentTitleID else { return nil }
        return container.config.unlocks.rule(id: id)?.localizedName
    }

    func skillProgress(_ skill: Skill) -> LevelProgress {
        container.config.skillCurve.progress(totalEXP: skill.totalEXP)
    }

    func allocatedPoints(for stat: CoreStatID) -> Int {
        player.allocatedPoints(for: stat)
    }

    func effectiveStatLevel(_ stat: CoreStatID) -> Int {
        statProgress(stat).level + player.allocatedPoints(for: stat)
    }

    func skillQuestBonus(for skill: Skill) -> Double {
        ProgressionEngine.bonus(
            level: skillProgress(skill).level,
            perLevel: container.config.balance.skillQuestBonusPerLevel,
            cap: container.config.balance.skillQuestBonusMax
        )
    }

    func skillXPBonus(for skill: Skill) -> Double {
        ProgressionEngine.skillXPMultiplier(
            affinities: skill.affinities,
            statLevels: Dictionary(uniqueKeysWithValues: CoreStatID.allCases.map { ($0, effectiveStatLevel($0)) }),
            perLevel: container.config.balance.statSkillXPBonusPerLevel,
            cap: container.config.balance.statSkillXPBonusMax
        )
    }

    var skillSlotCap: Int { max(1, player.skillSlotCap) }
    var learnedSkillCount: Int { skills.count }
    var canLearnSkill: Bool { learnedSkillCount < skillSlotCap }

    func statProgress(_ stat: CoreStatID) -> LevelProgress {
        container.config.statCurve.progress(totalEXP: player.exp(for: stat))
    }

    func luckyProgress() -> LevelProgress {
        container.config.statCurve.progress(totalEXP: player.luckyEXP)
    }

    var todayFortune: FortuneTier? {
        container.lucky.activeFortune(for: player, on: today)
    }

    func skills(feeding stat: CoreStatID) -> [Skill] {
        skills.filter { skill in
            skill.affinities.contains { $0.stat == stat && $0.weight > 0 }
        }
    }

    func habitProgress(_ habit: Habit) -> Int {
        container.habits.progress(for: habit, on: today)
    }

    func previewReward(for quest: Quest) -> RewardResult {
        container.quests.previewReward(for: quest, player: player)
    }

    // MARK: - 任务

    func createQuest(
        title: String,
        detail: String = "",
        difficulty: QuestDifficulty = .normal,
        priority: QuestPriority = .normal,
        tags: [String] = [],
        estimatedMinutes: Int = 30,
        scheduledDay: GameDay,
        dueAt: Date? = nil,
        skillShares: [SkillShare] = [],
        preferredKind: QuestKind? = nil
    ) {
        container.quests.createQuest(
            title: title,
            detail: detail,
            difficulty: difficulty,
            priority: priority,
            tags: tags,
            estimatedMinutes: estimatedMinutes,
            scheduledDay: scheduledDay,
            dueAt: dueAt,
            skillShares: skillShares,
            preferredKind: preferredKind
        )
        commit()
    }

    func updateQuest(
        _ quest: Quest,
        title: String,
        detail: String,
        difficulty: QuestDifficulty,
        priority: QuestPriority,
        tags: [String],
        estimatedMinutes: Int,
        scheduledDay: GameDay,
        dueAt: Date?,
        skillShares: [SkillShare]
    ) {
        container.quests.update(
            quest,
            title: title,
            detail: detail,
            difficulty: difficulty,
            priority: priority,
            tags: tags,
            estimatedMinutes: estimatedMinutes,
            scheduledDay: scheduledDay,
            dueAt: dueAt,
            skillShares: skillShares
        )
        commit()
    }

    func toggleQuest(_ quest: Quest) {
        container.quests.toggleCompletion(quest, player: player)
        evaluateUnlocks()
        commit()
    }

    func reschedule(_ quest: Quest, to day: GameDay) {
        container.quests.reschedule(quest, to: day)
        commit()
    }

    func deleteQuest(_ quest: Quest) {
        container.quests.delete(quest, player: player)
        commit()
    }

    func quests(on day: GameDay) -> [Quest] {
        QuestRepository(context: container.context).quests(on: day)
    }

    func upcomingQuests() -> [Quest] {
        QuestRepository(context: container.context).upcomingQuests(after: today)
    }

    // MARK: - 习惯

    func toggleHabit(_ habit: Habit) {
        container.habits.toggle(habit, player: player, on: today)
        evaluateUnlocks()
        commit()
    }

    func checkInHabit(_ habit: Habit) {
        container.habits.checkIn(habit, player: player, on: today)
        evaluateUnlocks()
        commit()
    }

    func undoHabit(_ habit: Habit) {
        container.habits.undoCheckIn(habit, player: player, on: today)
        commit()
    }

    func createHabit(
        name: String,
        iconName: String,
        colorHex: String,
        dailyTarget: Int,
        reminderHour: Int,
        reminderMinute: Int,
        skillShares: [SkillShare]
    ) {
        container.habits.createHabit(
            name: name,
            iconName: iconName,
            colorHex: colorHex,
            dailyTarget: dailyTarget,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            skillShares: skillShares
        )
        commit()
    }

    func deleteHabit(_ habit: Habit) {
        container.habits.delete(habit)
        commit()
    }

    // MARK: - 技能

    func createSkill(
        name: String,
        iconName: String,
        colorHex: String,
        catalogID: String = "",
        categories: [String] = [],
        affinities: [StatAffinity] = []
    ) -> Bool {
        guard canLearnSkill else { return false }
        let repository = SkillRepository(context: container.context)
        let skill = Skill(name: name, iconName: iconName, colorHex: colorHex, sortOrder: repository.allSkills().count)
        skill.catalogID = catalogID
        skill.categoryTokens = categories
        skill.affinities = affinities
        repository.insert(skill)
        commit()
        return true
    }

    @discardableResult
    func createSkill(from preset: SkillPreset) -> Bool {
        createSkill(
            name: preset.name,
            iconName: preset.icon,
            colorHex: preset.color,
            catalogID: preset.id,
            categories: preset.categories,
            affinities: preset.parsedAffinities
        )
    }

    func deleteSkill(_ skill: Skill) {
        let skillID = skill.id
        QuestRepository(context: container.context).detachSkill(skillID)
        let habits = HabitRepository(context: container.context)
        for habit in habits.allHabits(includeArchived: true) {
            habit.skillShares = habit.skillShares.filter { $0.skillID != skillID }
        }
        SkillRepository(context: container.context).delete(skill)
        commit()
    }

    func claimLevelUpStatBonus(_ stat: CoreStatID) {
        guard consumeLevelUpChoice() else { return }
        player.addAllocatedPoint(to: stat)
        commit()
    }

    func claimLevelUpSkillSlot() {
        guard let event = pendingLevelUpChoices.first, consumeLevelUpChoice() else { return }
        player.skillSlotCap += 1
        skillSlotFollowUp = event
        commit()
    }

    func dismissSkillSlotFollowUp() {
        skillSlotFollowUp = nil
    }

    // MARK: - 重复任务模板

    func templates() -> [QuestTemplate] {
        QuestRepository(context: container.context).allTemplates()
    }

    func createTemplate(
        title: String,
        detail: String,
        difficulty: QuestDifficulty,
        priority: QuestPriority,
        estimatedMinutes: Int,
        recurrence: RecurrenceRule,
        startPolicy: RecurrenceStartPolicy,
        skillShares: [SkillShare],
        tags: [String] = [],
        startDay: GameDay? = nil,
        endDay: GameDay? = nil
    ) {
        let template = QuestTemplate(
            title: title,
            detail: detail,
            difficulty: difficulty,
            priority: priority,
            tags: tags,
            estimatedMinutes: estimatedMinutes,
            recurrence: recurrence,
            startPolicy: startPolicy,
            startDay: startDay ?? today
        )
        template.endDay = endDay
        template.skillShares = skillShares
        QuestRepository(context: container.context).insert(template)
        runDayCycle()
    }

    func deleteTemplate(_ template: QuestTemplate) {
        QuestRepository(context: container.context).delete(template)
        commit()
    }

    // MARK: - 成长

    func challengeProgress() -> [(challenge: Challenge, progress: Double, text: String?)] {
        container.unlocks.challengeProgress(player: player)
    }

    func ruleProgress(kind: UnlockKind) -> [(rule: UnlockRule, progress: Double, text: String?, isUnlocked: Bool)] {
        container.unlocks.ruleProgress(player: player, kind: kind)
    }

    func unlockedTitles() -> [UnlockRule] {
        container.unlocks.unlockedTitles()
    }

    func createChallenge(
        title: String,
        detail: String,
        iconName: String,
        metricKey: String,
        metricParam: String?,
        threshold: Double,
        rewardEXP: Int,
        rewardGold: Int
    ) {
        let challenge = Challenge(
            title: title,
            detail: detail,
            iconName: iconName,
            metricKey: metricKey,
            metricParam: metricParam,
            threshold: threshold,
            rewardEXP: rewardEXP,
            rewardGold: rewardGold
        )
        ProgressionRepository(context: container.context).insert(challenge)
        evaluateUnlocks()
        commit()
    }

    func deleteChallenge(_ challenge: Challenge) {
        ProgressionRepository(context: container.context).delete(challenge)
        commit()
    }

    func markUnlocksSeen() {
        ProgressionRepository(context: container.context).markAllSeen()
        save()
    }

    func unseenUnlockCount() -> Int {
        ProgressionRepository(context: container.context).unseenUnlockCount()
    }

    func equipTitle(_ ruleID: String?) {
        player.currentTitleID = ruleID
        commit()
    }

    // MARK: - 商店

    /// 测试商店沙盒：忽略等级门槛，金币视为无限。
    var isTestShopSandboxEnabled: Bool { settings.testShopSandbox }

    func purchase(_ item: ShopItem) -> PurchaseError? {
        do {
            try container.shop.purchase(item, player: player, sandbox: isTestShopSandboxEnabled)
            commit()
            return nil
        } catch let error as PurchaseError {
            return error
        } catch {
            return nil
        }
    }

    func equip(_ item: ShopItem) {
        container.shop.equip(item, player: player)
        commit()
    }

    // MARK: - 设置

    func updateDayStartHour(_ hour: Int) {
        settings.dayStartHour = hour
        container.reloadCalendar(dayStartHour: hour)
        runDayCycle()
    }

    func setTestShopSandbox(_ enabled: Bool) {
        settings.testShopSandbox = enabled
        save()
    }

    func updateLanguage(_ language: AppLanguage) {
        settings.language = language
        applyLanguage(language)
        save()
        syncNotifications()
    }

    func syncNotifications() {
        let quests = QuestRepository(context: container.context).upcomingQuests(after: today)
        let habits = HabitRepository(context: container.context).allHabits()
        let settings = self.settings
        Task {
            await container.notifications.refreshAuthorizationStatus()
            await container.notifications.sync(habits: habits, quests: quests, settings: settings)
        }
    }

    // MARK: - 初始化 / 注销

    func completeOnboarding(nickname: String, skills: [OnboardingSkillDraft]) {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        player.nickname = trimmed.isEmpty ? Player.defaultNickname : trimmed
        player.skillSlotCap = max(1, container.config.balance.initialSkillSlots)

        let repository = SkillRepository(context: container.context)
        for (index, draft) in skills.prefix(player.skillSlotCap).enumerated() {
            let skill = Skill(
                name: draft.name,
                iconName: draft.iconName,
                colorHex: draft.colorHex,
                sortOrder: index
            )
            skill.catalogID = draft.catalogID
            skill.categoryTokens = draft.categories
            skill.affinities = draft.affinities
            repository.insert(skill)
        }

        settings.hasCompletedOnboarding = true
        needsOnboarding = false
        runDayCycle()
        syncNotifications()
    }

    /// 清空当前存档并回到初始化流程。内置挑战会在播种时重新对账。
    func resetAccount() throws {
        try container.export.resetSave()
        pendingLevelUps = []
        pendingLevelUpChoices = []
        skillSlotFollowUp = nil
        pendingUnlocks = []
        pendingFortunes = []
        _ = container.rewards.consumeLevelUps()
        _ = container.lucky.consumeEvents()
        container.bootstrap()
        reloadIdentities()
        refresh()
        save()
        Task {
            await container.notifications.cancelAll()
        }
    }

    /// 备份恢复后重新挂上身份、补齐内置挑战，并跳过初始化流程。
    func reloadAfterRestore() {
        container.bootstrap()
        reloadIdentities()
        settings.hasCompletedOnboarding = true
        needsOnboarding = false
        runDayCycle()
    }

    // MARK: - 内部

    private func reloadIdentities() {
        let repository = PlayerRepository(context: container.context)
        player = repository.currentPlayer()
        settings = repository.settings()
        applyLanguage(settings.language)
        needsOnboarding = !settings.hasCompletedOnboarding
        restoreUnclaimedLevelUpChoicesIfNeeded()
    }

    @discardableResult
    private func consumeLevelUpChoice() -> Bool {
        guard !pendingLevelUpChoices.isEmpty else { return false }
        pendingLevelUpChoices.removeFirst()
        player.unclaimedLevelUpChoices = max(0, player.unclaimedLevelUpChoices - 1)
        return true
    }

    private func restoreUnclaimedLevelUpChoicesIfNeeded() {
        let missing = player.unclaimedLevelUpChoices - pendingLevelUpChoices.count
        guard missing > 0 else { return }
        let firstLevel = player.highestLevelRewarded - player.unclaimedLevelUpChoices + 1
        for index in 0..<missing {
            pendingLevelUpChoices.append(
                LevelUpEvent(
                    skillName: nil,
                    level: max(2, firstLevel + index),
                    goldReward: 0,
                    requiresChoice: true
                )
            )
        }
    }

    private func applyLanguage(_ language: AppLanguage) {
        L10n.language = language
        languageCode = language.rawValue
    }

    private func commit() {
        refresh()
        save()
    }

    private func evaluateUnlocks() {
        let unlocked = container.unlocks.evaluate(player: player)
        if !unlocked.isEmpty {
            pendingUnlocks.append(contentsOf: unlocked)
        }
    }

    private func collectLevelUps() {
        let events = container.rewards.consumeLevelUps()
        for event in events {
            if event.requiresChoice {
                pendingLevelUpChoices.append(event)
            } else {
                pendingLevelUps.append(event)
            }
        }
        restoreUnclaimedLevelUpChoicesIfNeeded()
    }

    private func collectFortunes() {
        let events = container.lucky.consumeEvents()
        if !events.isEmpty {
            pendingFortunes.append(contentsOf: events)
        }
    }
}
