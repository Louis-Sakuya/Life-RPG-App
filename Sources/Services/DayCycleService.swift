import Foundation
import SwiftData

struct DayCycleReport: Sendable {
    var daysAdvanced: Int = 0
    var generatedQuests: Int = 0
    var markedOverdue: Int = 0
    var carriedOver: Int = 0
    var loginStreak: Int = 0
    var isFirstLaunchOfDay: Bool = false
    var newlyFailed: [FailedQuestSnapshot] = []
    var streakShieldTriggered: Bool = false
}

/// 每日结算。启动与回到前台时各跑一次。
///
/// 两条必须成立的性质：
/// - **可补算**：玩家几天没开应用时，逐日把每一天都结算掉，而不是只处理今天
/// - **幂等**：同一天重复执行不会重复发奖、不会重复生成任务
@MainActor
final class DayCycleService {
    /// 补算上限。用户手动改系统时间可能造成极端跨度，这里兜底避免长时间卡住启动。
    private static let maxCatchUpDays = 400

    private let context: ModelContext
    private let calendar: GameCalendar
    private let quests: QuestRepository
    private let habits: HabitRepository
    private let records: RecordRepository
    private let aggregates: DailyAggregateService

    init(context: ModelContext, calendar: GameCalendar) {
        self.context = context
        self.calendar = calendar
        self.quests = QuestRepository(context: context)
        self.habits = HabitRepository(context: context)
        self.records = RecordRepository(context: context)
        self.aggregates = DailyAggregateService(context: context)
    }

    @discardableResult
    func runIfNeeded(player: Player, settings: AppSettings) -> DayCycleReport {
        var report = DayCycleReport()
        let today = calendar.today

        if player.lastActiveDayValue == 0 {
            player.lastActiveDay = today
            player.totalDaysPlayed = max(1, player.totalDaysPlayed)
            report.isFirstLaunchOfDay = true
        } else if today > player.lastActiveDay {
            report = advance(player: player, settings: settings, to: today)
            report.isFirstLaunchOfDay = true
        }

        // 连续与生成逻辑本身是幂等的，因此每次启动都跑一遍，
        // 这样"今天新建了一个重复模板"也能立刻看到今天的实例。
        let paused = player.pausedDaySet
        report.streakShieldTriggered = applyStreakShieldIfNeeded(player: player, today: today)
        decayBrokenStreaks(player: player, today: today)
        settleAndGenerate(through: today, paused: paused, report: &report)
        report.markedOverdue = markOverdueQuests(before: today, paused: paused)
        report.newlyFailed.append(contentsOf: failExpiredSingles(on: today, paused: paused))
        advanceLoginStreak(player: player, on: today)
        aggregates.refresh(day: today)

        report.loginStreak = player.loginStreakCurrent
        return report
    }

    // MARK: - 逐日补算

    private func advance(player: Player, settings: AppSettings, to today: GameDay) -> DayCycleReport {
        var report = DayCycleReport()
        let firstPending = calendar.adding(days: 1, to: player.lastActiveDay)
        var pendingDays = calendar.days(from: firstPending, through: today)

        if pendingDays.count > Self.maxCatchUpDays {
            pendingDays = Array(pendingDays.suffix(Self.maxCatchUpDays))
        }

        for day in pendingDays {
            let previous = calendar.adding(days: -1, to: day)
            finalize(day: previous, player: player)
            if settings.carryOverUnfinished {
                report.carriedOver += carryOverUnfinished(from: previous, to: day)
            }
            report.daysAdvanced += 1
        }

        player.totalDaysPlayed += report.daysAdvanced
        player.lastActiveDay = today
        return report
    }

    /// 封存某一天。`isFinalized` 是幂等闸门，封存过的日子不再重复处理。
    private func finalize(day: GameDay, player: Player) {
        let record = records.ensureRecord(on: day)
        guard !record.isFinalized else { return }
        aggregates.refresh(day: day)
        if record.isPerfect {
            player.perfectDays += 1
        }
        record.isFinalized = true
        record.updatedAt = Date()
    }

    private func carryOverUnfinished(from day: GameDay, to target: GameDay) -> Int {
        let pending = quests.quests(on: day).filter { $0.status == .pending && $0.templateID == nil }
        for quest in pending {
            quest.scheduledDay = target
            quest.isOverdue = true
            if quest.overdueSinceDay == nil {
                quest.overdueSinceDay = target
            }
        }
        if !pending.isEmpty {
            aggregates.refresh(day: day)
            aggregates.refresh(day: target)
        }
        return pending.count
    }

    // MARK: - 周期窗口与实例

    private func settleAndGenerate(through today: GameDay, paused: Set<Int>, report: inout DayCycleReport) {
        for template in quests.activeTemplates() {
            if template.isFinished { continue }
            if let endDay = template.endDay, endDay < today { continue }
            bootstrapPeriod(template)
            settleWindows(template, on: today, paused: paused, report: &report)
            if !paused.contains(today.value),
               quests.ensurePendingRepeating(
                   template: template,
                   on: today,
                   calendar: calendar,
                   pausedDayValues: paused
               ) != nil {
                report.generatedQuests += 1
                aggregates.refresh(day: today)
            }
            template.lastGeneratedDay = today
        }
    }

    private func bootstrapPeriod(_ template: QuestTemplate) {
        let anchor = ScheduleEngine.effectiveStartDay(
            rule: template.recurrence,
            startDay: template.startDay,
            policy: template.startPolicy,
            calendar: calendar
        )
        if template.periodStartDayValue == 0 {
            template.periodStart = anchor
        }
        if template.cycleOriginDayValue == 0 {
            template.cycleOrigin = template.periodStart
        }
    }

    private func settleWindows(
        _ template: QuestTemplate,
        on day: GameDay,
        paused: Set<Int>,
        report: inout DayCycleReport
    ) {
        var steps = 0
        while RecurringPeriodEngine.windowHasEnded(
            start: template.periodStart,
            on: day,
            calendar: calendar,
            pausedDayValues: paused
        ), steps < 60 {
            closeWindow(template, on: day, paused: paused, report: &report)
            steps += 1
        }
    }

    private func closeWindow(
        _ template: QuestTemplate,
        on day: GameDay,
        paused: Set<Int>,
        report: inout DayCycleReport
    ) {
        let anchor = ScheduleEngine.effectiveStartDay(
            rule: template.recurrence,
            startDay: template.startDay,
            policy: template.startPolicy,
            calendar: calendar
        )
        let quotaStart = template.periodState == .grace ? template.cycleOrigin : template.periodStart
        let windowEnd = RecurringPeriodEngine.lastDayOfWindow(
            start: template.periodStart,
            calendar: calendar,
            pausedDayValues: paused
        )
        let quota = RecurringPeriodEngine.periodQuota(
            rule: template.recurrence,
            maxPerDay: template.maxCompletionsPerDay,
            periodStart: quotaStart,
            anchor: anchor,
            calendar: calendar,
            pausedDayValues: paused
        )
        let completed = quests.completedCount(
            templateID: template.id,
            from: quotaStart,
            through: windowEnd
        )
        let nextStart = calendar.adding(days: 1, to: windowEnd)
        let met = quota == 0 || completed >= quota
        if met, quota > 0, completed >= quota {
            template.completedJourneys += 1
        }

        if template.periodState == .active {
            if met {
                beginPeriod(template, on: nextStart, state: .active)
            } else {
                beginPeriod(template, on: nextStart, state: .grace, keepOrigin: true)
                markTemplatePendingOverdue(template, since: nextStart)
            }
        } else if met {
            beginPeriod(template, on: nextStart, state: .active)
        } else {
            failTemplatePeriod(
                template,
                start: quotaStart,
                end: windowEnd,
                completed: completed,
                quota: max(1, quota),
                on: day,
                report: &report
            )
            beginPeriod(template, on: nextStart, state: .active)
        }
    }

    private func beginPeriod(
        _ template: QuestTemplate,
        on start: GameDay,
        state: RecurringPeriodState,
        keepOrigin: Bool = false
    ) {
        template.periodStart = start
        template.periodState = state
        if !keepOrigin {
            template.cycleOrigin = start
        }
    }

    private func markTemplatePendingOverdue(_ template: QuestTemplate, since day: GameDay) {
        for quest in quests.pendingRepeating(templateID: template.id) {
            quest.isOverdue = true
            if quest.overdueSinceDay == nil {
                quest.overdueSinceDay = day
            }
        }
    }

    private func failTemplatePeriod(
        _ template: QuestTemplate,
        start: GameDay,
        end: GameDay,
        completed: Int,
        quota: Int,
        on day: GameDay,
        report: inout DayCycleReport
    ) {
        let record = FailedQuestRecord(
            title: template.title,
            detail: template.detail,
            kind: .repeating,
            scheduledStart: start,
            scheduledEnd: end,
            failedDay: day,
            progressDone: completed,
            progressTarget: quota,
            templateID: template.id
        )
        quests.insert(record)
        report.newlyFailed.append(FailedQuestSnapshot(record))
        for quest in quests.pendingRepeating(templateID: template.id) {
            quest.status = .cancelled
            aggregates.refresh(day: quest.scheduledDay)
        }
    }

    // MARK: - 延期与单项失败

    @discardableResult
    private func markOverdueQuests(before day: GameDay, paused: Set<Int>) -> Int {
        if paused.contains(day.value) { return 0 }
        let stale = quests.unfinishedQuests(before: day)
        var marked = 0
        for quest in stale where !quest.isOverdue {
            if quest.templateID != nil { continue }
            // 跨多日的长期委托以截止日为准，开始日过了但还没到截止日不算逾期
            if let dueAt = quest.dueAt, calendar.gameDay(for: dueAt) >= day {
                continue
            }
            quest.isOverdue = true
            if quest.overdueSinceDay == nil {
                quest.overdueSinceDay = day
            }
            marked += 1
        }
        return marked
    }

    private func failExpiredSingles(on today: GameDay, paused: Set<Int>) -> [FailedQuestSnapshot] {
        if paused.contains(today.value) { return [] }
        var failed: [FailedQuestSnapshot] = []
        for quest in quests.pendingQuests() where quest.templateID == nil {
            let dueDay = quest.dueAt.map { calendar.gameDay(for: $0) }
            guard RecurringPeriodEngine.shouldFailSingle(
                scheduledDay: quest.scheduledDay,
                dueDay: dueDay,
                today: today,
                calendar: calendar,
                pausedDayValues: paused
            ) else { continue }

            let record = FailedQuestRecord(
                title: quest.title,
                detail: quest.detail,
                kind: quest.kind,
                scheduledStart: quest.scheduledDay,
                scheduledEnd: dueDay ?? quest.scheduledDay,
                failedDay: today,
                progressDone: 0,
                progressTarget: 1,
                originalQuestID: quest.id
            )
            quests.insert(record)
            quest.status = .cancelled
            aggregates.refresh(day: quest.scheduledDay)
            failed.append(FailedQuestSnapshot(record))
        }
        return failed
    }

    // MARK: - 连续

    private func applyStreakShieldIfNeeded(player: Player, today: GameDay) -> Bool {
        guard player.hasStreakShield else { return false }
        let (protected, triggered) = StreakEngine.applyShield(player.loginStreak, today: today, calendar: calendar)
        guard triggered else { return false }
        player.loginStreak = protected
        player.hasStreakShield = false
        player.pendingStreakShieldAlert = true
        return true
    }

    private func advanceLoginStreak(player: Player, on day: GameDay) {
        player.loginStreak = StreakEngine.advance(player.loginStreak, on: day, calendar: calendar)
    }

    /// 把早已中断的连续清零。不做这一步的话，界面会一直显示一个虚高的数字，
    /// 而奖励引擎也会继续按这个数字发放连续加成。
    private func decayBrokenStreaks(player: Player, today: GameDay) {
        player.loginStreak = StreakEngine.decayIfBroken(player.loginStreak, today: today, calendar: calendar)
        for habit in habits.allHabits() {
            habit.streak = StreakEngine.decayIfBroken(habit.streak, today: today, calendar: calendar)
        }
        for template in quests.allTemplates() {
            template.streak = StreakEngine.decayIfBroken(template.streak, today: today, calendar: calendar)
        }
    }
}
