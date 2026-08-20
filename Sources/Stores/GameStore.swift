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
    private(set) var overdueQuests: [Quest] = []
    private(set) var habits: [Habit] = []
    private(set) var skills: [Skill] = []
    private(set) var todayRecord: DailyRecord?
    private(set) var palette: ThemePalette = .default

    /// 待展示的庆祝弹窗。视图消费后清空，避免同一个升级重复弹。
    var pendingLevelUps: [LevelUpEvent] = []
    var pendingUnlocks: [UnlockRule] = []

    private var hasBootstrapped = false

    init(container: AppContainer) {
        self.container = container
        let repository = PlayerRepository(context: container.context)
        self.player = repository.currentPlayer()
        self.settings = repository.settings()
        self.today = container.calendar.today
    }

    // MARK: - 生命周期

    func bootstrap() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        container.bootstrap()
        let repository = PlayerRepository(context: container.context)
        player = repository.currentPlayer()
        settings = repository.settings()
        runDayCycle()
    }

    /// 回到前台时调用。跨过午夜的场景就是靠这里被捕捉到的。
    func onForeground() {
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

        todayQuests = questRepo.quests(on: today)
        overdueQuests = questRepo.unfinishedQuests(before: today)
        habits = habitRepo.allHabits()
        skills = skillRepo.allSkills()
        todayRecord = recordRepo.record(on: today)
        palette = container.shop.palette(for: player)

        collectLevelUps()
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

    var todayEXP: Int { todayRecord?.expEarned ?? 0 }
    var todayGold: Int { todayRecord?.goldEarned ?? 0 }
    var todayCompletionRate: Double { todayRecord?.completionRate ?? 0 }

    var streakMultiplier: Double {
        StreakEngine.multiplier(forDays: player.loginStreakCurrent, tiers: container.config.balance.streakTiers)
    }

    var nextStreakTier: BalanceConfig.StreakTier? {
        StreakEngine.nextTier(forDays: player.loginStreakCurrent, tiers: container.config.balance.streakTiers)
    }

    var currentTitleName: String? {
        guard let id = player.currentTitleID else { return nil }
        return container.config.unlocks.rule(id: id)?.name
    }

    func skillProgress(_ skill: Skill) -> LevelProgress {
        container.config.skillCurve.progress(totalEXP: skill.totalEXP)
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
        skillShares: [SkillShare] = []
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
            skillShares: skillShares
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

    func createSkill(name: String, iconName: String, colorHex: String) {
        let repository = SkillRepository(context: container.context)
        repository.insert(
            Skill(name: name, iconName: iconName, colorHex: colorHex, sortOrder: repository.allSkills().count)
        )
        commit()
    }

    func deleteSkill(_ skill: Skill) {
        SkillRepository(context: container.context).delete(skill)
        commit()
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
        skillShares: [SkillShare]
    ) {
        let template = QuestTemplate(
            title: title,
            detail: detail,
            difficulty: difficulty,
            priority: priority,
            estimatedMinutes: estimatedMinutes,
            recurrence: recurrence,
            startPolicy: startPolicy,
            startDay: today
        )
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

    func purchase(_ item: ShopItem) -> PurchaseError? {
        do {
            try container.shop.purchase(item, player: player)
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

    func syncNotifications() {
        let quests = QuestRepository(context: container.context).upcomingQuests(after: today)
        let habits = HabitRepository(context: container.context).allHabits()
        let settings = self.settings
        Task {
            await container.notifications.refreshAuthorizationStatus()
            await container.notifications.sync(habits: habits, quests: quests, settings: settings)
        }
    }

    // MARK: - 内部

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
        if !events.isEmpty {
            pendingLevelUps.append(contentsOf: events)
        }
    }
}
