import Foundation
import SwiftData

struct DayCycleReport: Sendable {
    var daysAdvanced: Int = 0
    var generatedQuests: Int = 0
    var markedOverdue: Int = 0
    var carriedOver: Int = 0
    var loginStreak: Int = 0
    var isFirstLaunchOfDay: Bool = false
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
    /// 重复任务的最大回溯生成窗口。长期未打开应用时不应该被几十条过期任务淹没。
    private static let templateLookbackDays = 7

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
        decayBrokenStreaks(player: player, today: today)
        report.generatedQuests += generateTemplateQuests(through: today)
        report.markedOverdue = markOverdueQuests(before: today)
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
        let pending = quests.quests(on: day).filter { $0.status == .pending }
        for quest in pending {
            quest.scheduledDay = target
            quest.isOverdue = true
        }
        if !pending.isEmpty {
            aggregates.refresh(day: day)
            aggregates.refresh(day: target)
        }
        return pending.count
    }

    // MARK: - 重复任务生成

    @discardableResult
    private func generateTemplateQuests(through today: GameDay) -> Int {
        var generated = 0
        let earliestAllowed = calendar.adding(days: -Self.templateLookbackDays, to: today)

        for template in quests.activeTemplates() {
            if let endDay = template.endDay, endDay < today { continue }

            let anchor = ScheduleEngine.effectiveStartDay(
                rule: template.recurrence,
                startDay: template.startDay,
                policy: template.startPolicy,
                calendar: calendar
            )

            var start = anchor
            if let lastGenerated = template.lastGeneratedDay {
                start = max(start, calendar.adding(days: 1, to: lastGenerated))
            }
            start = max(start, earliestAllowed)
            guard start <= today else { continue }

            let days = ScheduleEngine.occurrences(
                rule: template.recurrence,
                in: start...today,
                anchor: anchor,
                calendar: calendar
            )

            for day in days {
                if let endDay = template.endDay, day > endDay { continue }
                guard !quests.hasGeneratedQuest(templateID: template.id, on: day) else { continue }
                let quest = Quest(
                    title: template.title,
                    detail: template.detail,
                    kind: .repeating,
                    difficulty: template.difficulty,
                    priority: template.priority,
                    tags: template.tags,
                    estimatedMinutes: template.estimatedMinutes,
                    createdDay: day,
                    scheduledDay: day,
                    templateID: template.id
                )
                quests.insert(quest, skillShares: template.skillShares)
                aggregates.refresh(day: day)
                generated += 1
            }

            template.lastGeneratedDay = today
        }
        return generated
    }

    // MARK: - 延期标记

    @discardableResult
    private func markOverdueQuests(before day: GameDay) -> Int {
        let stale = quests.unfinishedQuests(before: day)
        for quest in stale where !quest.isOverdue {
            quest.isOverdue = true
        }
        return stale.count
    }

    // MARK: - 连续

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
