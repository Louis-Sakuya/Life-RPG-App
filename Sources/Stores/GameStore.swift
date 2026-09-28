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
    /// 当前主标签。新手引导期间用来把玩家带到成长页。
    var selectedTab = 0
    private(set) var tutorialStep: TutorialStep?
    var tutorialOpenPublish = false
    var tutorialForceHabitsTab = false
    var tutorialOpenHabitEditor = false
    var tutorialHabitReadyForDone = false

    /// 待选择的玩家升级额外奖励。金币已经发放，这里只处理属性点或技能栏位。
    var pendingLevelUpChoices: [LevelUpEvent] = []
    /// 刚选了技能栏位时，先把“现在学习 / 稍后”留在界面上。
    var skillSlotFollowUp: LevelUpEvent?
    var pendingLevelUps: [LevelUpEvent] = []
    var pendingUnlocks: [UnlockRule] = []
    var pendingFortunes: [FortuneEvent] = []
    /// 当天第一次打开时弹出的失败任务清单
    var pendingFailedQuests: [FailedQuestSnapshot] = []
    var completeFXToken: UUID?
    var levelFXToken: UUID?
    var rewardPopup: RewardPopupEvent?
    var rowSparkSourceID: UUID?

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
            syncNotifications()
        }
    }

    /// 回到前台时调用。跨过午夜的场景就是靠这里被捕捉到的。
    func onForeground() {
        guard !needsOnboarding else { return }
        runDayCycle()
        // 未打开提醒从这次打开重新计时；任务截止提醒也一并按当前待办重排
        syncNotifications()
    }

    /// 进入后台时把未打开提醒的计时点定在离开这一刻。
    func onBackground() {
        save()
        guard !needsOnboarding else { return }
        syncNotifications()
    }

    private func runDayCycle() {
        today = container.calendar.today
        let report = container.dayCycle.runIfNeeded(player: player, settings: settings)
        if report.isFirstLaunchOfDay, !report.newlyFailed.isEmpty {
            pendingFailedQuests = report.newlyFailed
        }
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
        for quest in todayQuests where quest.isOverdue && !quest.isCompleted {
            if !overdueQuests.contains(where: { $0.id == quest.id }) {
                overdueQuests.append(quest)
            }
        }
        spanningQuests = unfinished.filter { quest in
            guard let dueAt = quest.dueAt else { return false }
            return container.calendar.gameDay(for: dueAt) >= today
        }
        habits = habitRepo.allHabits()
        skills = skillRepo.allSkills()
        todayRecord = recordRepo.record(on: today)
        container.shop.normalizeEquipment(player)
        palette = container.shop.palette(for: player)

        collectLevelUps()
        collectFortunes()
        catchUpTutorial()
    }

    private func catchUpTutorial() {
        guard isTutorialActive, let step = tutorialStep else { return }
        if hasAnyHabit, [.goGrowth, .pickHabits, .tapAddHabit, .fillHabit].contains(step) {
            advanceTutorial(to: .done)
        }
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

    /// 工会任务栏上的主线：今天的主线 / 重复实例，仍在截止日期内的跨日委托，以及逾期未结的主线。
    /// 当天完成的任务留在栏上划掉并沉底，不从列表里拿掉。
    var guildMainQuests: [Quest] {
        mergedBoard(
            primary: mainQuests,
            extra: boardExtras.filter { $0.kind != .side },
            completedToday: todayCompletedQuests.filter { $0.kind != .side }
        )
    }

    var guildSideQuests: [Quest] {
        mergedBoard(
            primary: sideQuests,
            extra: boardExtras.filter { $0.kind == .side },
            completedToday: todayCompletedQuests.filter { $0.kind == .side }
        )
    }

    /// 全部任务子面板：主线与支线按优先度排在同一栏。
    var guildAllQuests: [Quest] {
        mergedBoard(
            primary: todayQuests,
            extra: boardExtras,
            completedToday: todayCompletedQuests
        )
    }

    private var boardExtras: [Quest] {
        spanningQuests + overdueQuests
    }

    var todayHabitCompletedCount: Int {
        habits.filter { habitProgress($0) >= max(1, $0.dailyTarget) }.count
    }

    var todayHabitTotalCount: Int { habits.count }

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

    var equippedBackgroundStyle: String? {
        guard !player.currentBackgroundID.isEmpty,
              let item = container.config.shop.item(id: player.currentBackgroundID),
              item.kind == .background else { return nil }
        return item.styleID
    }

    var equippedPet: ShopItem? {
        guard !player.currentPetID.isEmpty else { return nil }
        return container.config.shop.item(id: player.currentPetID)
    }

    var equippedFrame: ShopItem? {
        guard let id = player.currentFrameID else { return nil }
        return container.config.shop.item(id: id)
    }

    var hasClassicSFX: Bool { player.currentSoundID == "sfx_classic" }
    var hasCompleteSpark: Bool { player.currentCompleteEffectID == "fx_complete_spark" }
    var hasLevelBurst: Bool { player.currentLevelEffectID == "fx_levelup_burst" }

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
        noteQuestCreated(kind: preferredKind)
        commit()
        syncNotifications()
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
        syncNotifications()
    }

    func toggleQuest(_ quest: Quest) {
        let completing = !quest.isCompleted
        let result = container.quests.toggleCompletion(quest, player: player)
        evaluateUnlocks()
        if completing, let result {
            presentCompletionFeedback(sourceID: quest.id, exp: result.exp, gold: result.gold)
        }
        commit()
        syncNotifications()
    }

    func reschedule(_ quest: Quest, to day: GameDay) {
        container.quests.reschedule(quest, to: day)
        commit()
        syncNotifications()
    }

    func deleteQuest(_ quest: Quest) {
        container.quests.delete(quest, player: player)
        commit()
        syncNotifications()
    }

    func quests(on day: GameDay) -> [Quest] {
        QuestRepository(context: container.context).quests(on: day)
    }

    func upcomingQuests() -> [Quest] {
        QuestRepository(context: container.context).upcomingQuests(after: today)
    }

    // MARK: - 习惯

    func toggleHabit(_ habit: Habit) {
        let result = container.habits.toggle(habit, player: player, on: today)
        evaluateUnlocks()
        if let result {
            presentCompletionFeedback(sourceID: habit.id, exp: result.exp, gold: result.gold)
        }
        commit()
    }

    func checkInHabit(_ habit: Habit) {
        let result = container.habits.checkIn(habit, player: player, on: today)
        evaluateUnlocks()
        if let result {
            presentCompletionFeedback(sourceID: habit.id, exp: result.exp, gold: result.gold)
        } else {
            GameHaptics.soft()
            playCue(.checkIn)
        }
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
        noteHabitCreated()
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
            .sorted { lhs, rhs in
                if lhs.isFinished != rhs.isFinished { return !lhs.isFinished }
                return lhs.createdAt < rhs.createdAt
            }
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
        endDay: GameDay? = nil,
        maxCompletionsPerDay: Int = 1
    ) {
        let start = startDay ?? today
        let template = QuestTemplate(
            title: title,
            detail: detail,
            difficulty: difficulty,
            priority: priority,
            tags: tags,
            estimatedMinutes: estimatedMinutes,
            recurrence: recurrence,
            startPolicy: startPolicy,
            startDay: start
        )
        let anchor = ScheduleEngine.effectiveStartDay(
            rule: recurrence,
            startDay: start,
            policy: startPolicy,
            calendar: container.calendar
        )
        template.maxCompletionsPerDay = max(1, maxCompletionsPerDay)
        template.periodStart = anchor
        template.cycleOrigin = anchor
        template.endDay = endDay
        template.skillShares = skillShares
        QuestRepository(context: container.context).insert(template)
        noteQuestCreated(kind: .repeating)
        runDayCycle()
    }

    func deleteTemplate(_ template: QuestTemplate) {
        QuestRepository(context: container.context).delete(template)
        commit()
    }

    func previewFinishTemplate(_ template: QuestTemplate) -> RecurringFinishReward {
        container.quests.previewFinish(template)
    }

    func finishTemplate(_ template: QuestTemplate) {
        guard let reward = container.quests.finishTemplate(template, player: player) else { return }
        evaluateUnlocks()
        presentCompletionFeedback(sourceID: template.id, exp: reward.exp, gold: reward.gold)
        commit()
        syncNotifications()
    }

    func template(id: UUID) -> QuestTemplate? {
        QuestRepository(context: container.context).template(id: id)
    }

    func failedQuestRecords() -> [FailedQuestRecord] {
        QuestRepository(context: container.context).allFailedRecords()
    }

    func repeatingProgress(for quest: Quest) -> (remaining: Int, dailyLeft: Int, isGrace: Bool)? {
        guard let templateID = quest.templateID,
              let template = QuestRepository(context: container.context).template(id: templateID) else {
            return nil
        }
        let paused = player.pausedDaySet
        let calendar = container.calendar
        let anchor = ScheduleEngine.effectiveStartDay(
            rule: template.recurrence,
            startDay: template.startDay,
            policy: template.startPolicy,
            calendar: calendar
        )
        let quotaStart = template.periodState == .grace ? template.cycleOrigin : template.periodStart
        let quota = RecurringPeriodEngine.periodQuota(
            rule: template.recurrence,
            maxPerDay: template.maxCompletionsPerDay,
            periodStart: quotaStart,
            anchor: anchor,
            calendar: calendar,
            pausedDayValues: paused
        )
        let windowEnd = RecurringPeriodEngine.lastDayOfWindow(
            start: template.periodStart,
            calendar: calendar,
            pausedDayValues: paused
        )
        let repo = QuestRepository(context: container.context)
        let completed = repo.completedCount(templateID: template.id, from: quotaStart, through: max(windowEnd, today))
        let remaining = RecurringPeriodEngine.remaining(quota: quota, completed: completed)
        let doneToday = repo.completedCount(templateID: template.id, on: today)
        let dailyLeft = max(0, max(1, template.maxCompletionsPerDay) - doneToday)
        return (remaining, dailyLeft, template.periodState == .grace)
    }

    func isTodayPaused() -> Bool {
        player.isPaused(today)
    }

    func useLeaveCard(on day: GameDay) -> Bool {
        guard player.leaveCardCount > 0 else { return false }
        guard day >= today else { return false }
        guard !player.isPaused(day) else { return false }
        player.leaveCardCount -= 1
        player.pause(day)
        commit()
        return true
    }

    func dismissFailedQuestAlert() {
        pendingFailedQuests = []
    }

    func dismissStreakShieldAlert() {
        player.pendingStreakShieldAlert = false
        save()
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
            playCue(.purchase)
            commit()
            if item.kind == .consumable {
                syncNotifications()
            }
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

    func updateAvatar(symbol: String, imageData: Data?) {
        player.avatarSymbol = symbol.isEmpty ? Player.defaultAvatarSymbol : symbol
        player.avatarImageData = imageData
        commit()
    }

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
        let dueQuests: [NotificationPlanner.DueQuest] = QuestRepository(context: container.context)
            .pendingQuests()
            .compactMap { quest in
                guard let dueAt = quest.dueAt else { return nil }
                return NotificationPlanner.DueQuest(id: quest.id, title: quest.title, dueAt: dueAt)
            }
        let settings = self.settings
        Task {
            await container.notifications.refreshAuthorizationStatus()
            await container.notifications.sync(
                dueQuests: dueQuests,
                settings: settings
            )
        }
    }

    // MARK: - 初始化 / 注销

    func completeOnboarding(
        nickname: String,
        avatarSymbol: String = Player.defaultAvatarSymbol,
        avatarImageData: Data? = nil,
        skills: [OnboardingSkillDraft]
    ) {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        player.nickname = trimmed.isEmpty ? Player.defaultNickname : trimmed
        player.avatarSymbol = avatarSymbol.isEmpty ? Player.defaultAvatarSymbol : avatarSymbol
        player.avatarImageData = avatarImageData
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
        startTutorial()
        runDayCycle()
        syncNotifications()
    }

    /// 清空当前存档。测试里就地重建；真机先退出，下次启动再清档，避免界面读到已删除的模型。
    func resetAccount() throws {
        pendingLevelUps = []
        pendingLevelUpChoices = []
        skillSlotFollowUp = nil
        pendingUnlocks = []
        pendingFortunes = []
        pendingFailedQuests = []
        todayQuests = []
        todayCompletedQuests = []
        overdueQuests = []
        spanningQuests = []
        habits = []
        skills = []
        todayRecord = nil
        tutorialStep = nil
        tutorialOpenPublish = false
        tutorialForceHabitsTab = false
        tutorialOpenHabitEditor = false
        tutorialHabitReadyForDone = false
        completeFXToken = nil
        levelFXToken = nil
        rewardPopup = nil
        rowSparkSourceID = nil
        _ = container.rewards.consumeLevelUps()
        _ = container.lucky.consumeEvents()
        try container.export.resetSave()
        container.bootstrap()
        reloadIdentities()
        refresh()
        save()
        Task {
            await container.notifications.cancelAll()
        }
    }

    func requestAccountReset() {
        ExportService.markPendingResetAndTerminate()
    }

    /// 备份恢复后重新挂上身份、补齐内置挑战，并跳过初始化流程。
    func reloadAfterRestore() {
        container.bootstrap()
        reloadIdentities()
        settings.hasCompletedOnboarding = true
        settings.hasCompletedTutorial = true
        settings.tutorialStepRaw = ""
        needsOnboarding = false
        tutorialStep = nil
        runDayCycle()
    }

    // MARK: - 新手引导

    var isTutorialActive: Bool {
        tutorialStep != nil && !settings.hasCompletedTutorial
    }

    func selectTab(_ tab: Int) {
        guard isTutorialActive else {
            selectedTab = tab
            return
        }
        switch tutorialStep {
        case .goGrowth where tab == 1:
            selectedTab = 1
            advanceTutorial(to: .pickHabits)
        case .pickHabits, .tapAddHabit, .fillHabit, .done:
            if tab == 1 { selectedTab = 1 }
        default:
            if tab == 0 { selectedTab = 0 }
        }
    }

    func performTutorialPrimary() {
        switch tutorialStep {
        case .welcome:
            advanceTutorial(to: .tapPublishMain)
        case .done:
            completeTutorial()
        default:
            break
        }
    }

    func performTutorialHighlightAction() {
        switch tutorialStep {
        case .tapPublishMain:
            tutorialOpenPublish = true
            advanceTutorial(to: .pickMain)
        case .tapPublishSide:
            tutorialOpenPublish = true
            advanceTutorial(to: .pickSide)
        case .pickMain:
            advanceTutorial(to: .pickUrgent)
        case .pickUrgent:
            advanceTutorial(to: .fillMain)
        case .pickSide:
            advanceTutorial(to: .fillSide)
        case .goGrowth:
            selectedTab = 1
            advanceTutorial(to: .pickHabits)
        case .pickHabits:
            selectedTab = 1
            tutorialForceHabitsTab = true
            advanceTutorial(to: .tapAddHabit)
        case .tapAddHabit:
            tutorialOpenHabitEditor = true
            advanceTutorial(to: .fillHabit)
        default:
            break
        }
    }

    private func startTutorial() {
        settings.hasCompletedTutorial = false
        selectedTab = 0
        advanceTutorial(to: .welcome)
    }

    private func restoreTutorial() {
        if settings.hasCompletedTutorial {
            tutorialStep = nil
            return
        }
        guard let stored = TutorialStep(rawValue: settings.tutorialStepRaw) else {
            tutorialStep = nil
            return
        }
        var entry = stored.resumeEntry
        if hasAnyHabit, [.goGrowth, .pickHabits, .tapAddHabit, .fillHabit].contains(entry) {
            entry = .done
        }
        tutorialStep = entry
        settings.tutorialStepRaw = entry.rawValue
        if entry == .goGrowth {
            selectedTab = 0
        }
    }

    private var hasAnyHabit: Bool {
        !habits.isEmpty || !HabitRepository(context: container.context).allHabits().isEmpty
    }

    private func advanceTutorial(to step: TutorialStep) {
        var next = step
        if hasAnyHabit, [.goGrowth, .pickHabits, .tapAddHabit, .fillHabit].contains(step) {
            next = .done
        }
        tutorialStep = next
        settings.tutorialStepRaw = next.rawValue
        if next != .done {
            settings.hasCompletedTutorial = false
        }
        save()
    }

    private func completeTutorial() {
        tutorialStep = nil
        settings.tutorialStepRaw = ""
        settings.hasCompletedTutorial = true
        save()
    }

    private func noteQuestCreated(kind: QuestKind?) {
        guard isTutorialActive else { return }
        if tutorialStep == .fillMain, kind == .main || kind == .repeating || kind == nil {
            advanceTutorial(to: .tapPublishSide)
        } else if tutorialStep == .fillSide, kind == .side {
            advanceTutorial(to: .goGrowth)
            selectedTab = 0
        }
    }

    private func noteHabitCreated() {
        guard isTutorialActive else { return }
        switch tutorialStep {
        case .goGrowth, .pickHabits, .tapAddHabit, .fillHabit:
            tutorialOpenHabitEditor = false
            tutorialHabitReadyForDone = false
            selectedTab = 1
            advanceTutorial(to: .done)
        default:
            break
        }
    }

    func completeTutorialHabitIfNeeded() {
        guard isTutorialActive else { return }
        guard tutorialStep == .fillHabit || tutorialHabitReadyForDone else { return }
        tutorialHabitReadyForDone = false
        selectedTab = 1
        if hasAnyHabit {
            advanceTutorial(to: .done)
        }
    }

    func noteHabitEditorPresented() {
        guard isTutorialActive else { return }
        if tutorialStep == .pickHabits || tutorialStep == .tapAddHabit {
            advanceTutorial(to: .fillHabit)
        }
    }

    // MARK: - 内部

    private func reloadIdentities() {
        let repository = PlayerRepository(context: container.context)
        player = repository.currentPlayer()
        settings = repository.settings()
        applyLanguage(settings.language)
        needsOnboarding = !settings.hasCompletedOnboarding
        restoreTutorial()
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
            playCue(.levelUp)
            GameHaptics.success()
            fireLevelFX()
        }
        restoreUnclaimedLevelUpChoicesIfNeeded()
    }

    private func collectFortunes() {
        let events = container.lucky.consumeEvents()
        if !events.isEmpty {
            pendingFortunes.append(contentsOf: events)
        }
    }

    private func presentCompletionFeedback(sourceID: UUID, exp: Int, gold: Int) {
        GameHaptics.light()
        playCue(.complete)
        let popup = RewardPopupEvent(sourceID: sourceID, exp: exp, gold: gold)
        rewardPopup = popup
        rowSparkSourceID = sourceID
        if hasCompleteSpark {
            fireCompleteFX()
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(520))
            if rowSparkSourceID == sourceID {
                rowSparkSourceID = nil
            }
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1250))
            if rewardPopup?.id == popup.id {
                rewardPopup = nil
            }
        }
    }

    private func playCue(_ cue: SoundCue) {
        guard hasClassicSFX else { return }
        SoundService.shared.play(cue)
    }

    private func fireCompleteFX() {
        completeFXToken = UUID()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1100))
            completeFXToken = nil
        }
    }

    private func fireLevelFX() {
        levelFXToken = UUID()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1300))
            levelFXToken = nil
        }
    }
}
