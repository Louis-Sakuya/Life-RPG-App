import Foundation

/// 周期任务的窗口、配额与逾期判定。暂停日不计入活跃天数，
/// 这样请假不会把「下周三才到期」提前推成失败。
enum RecurringPeriodEngine {
    static let windowActiveDays = 7
    static let singleFailAfterActiveDays = 3

    /// 从 `start` 起数满 `activeLength` 个未暂停日，返回窗口最后一天。
    static func lastDayOfWindow(
        start: GameDay,
        calendar: GameCalendar,
        pausedDayValues: Set<Int>,
        activeLength: Int = windowActiveDays
    ) -> GameDay {
        var remaining = max(1, activeLength)
        var cursor = start
        var steps = 0
        while remaining > 0 && steps < 400 {
            if !pausedDayValues.contains(cursor.value) {
                remaining -= 1
                if remaining == 0 { return cursor }
            }
            cursor = calendar.adding(days: 1, to: cursor)
            steps += 1
        }
        return cursor
    }

    static func windowHasEnded(
        start: GameDay,
        on day: GameDay,
        calendar: GameCalendar,
        pausedDayValues: Set<Int>
    ) -> Bool {
        day > lastDayOfWindow(start: start, calendar: calendar, pausedDayValues: pausedDayValues)
    }

    /// `(from, to]` 之间未暂停的天数。
    static func activeDaysBetween(
        _ from: GameDay,
        _ to: GameDay,
        calendar: GameCalendar,
        pausedDayValues: Set<Int>
    ) -> Int {
        guard to > from else { return 0 }
        return calendar.days(from: calendar.adding(days: 1, to: from), through: to)
            .filter { !pausedDayValues.contains($0.value) }
            .count
    }

    static func periodQuota(
        rule: RecurrenceRule,
        maxPerDay: Int,
        periodStart: GameDay,
        anchor: GameDay,
        calendar: GameCalendar,
        pausedDayValues: Set<Int>
    ) -> Int {
        let cap = max(1, maxPerDay)
        switch rule {
        case .timesPerWeek(let count):
            return max(1, min(7 * cap, count))
        case .weekly(let weekdays):
            return max(1, weekdays.filter { (1...7).contains($0) }.count)
        case .daily, .monthly:
            let end = lastDayOfWindow(
                start: periodStart,
                calendar: calendar,
                pausedDayValues: pausedDayValues
            )
            let hits = calendar.days(from: periodStart, through: end).filter { day in
                !pausedDayValues.contains(day.value)
                    && ScheduleEngine.occurs(rule: rule, on: day, anchor: anchor, calendar: calendar)
            }
            return hits.count * cap
        }
    }

    static func remaining(quota: Int, completed: Int) -> Int {
        max(0, quota - max(0, completed))
    }

    static func canComplete(
        on day: GameDay,
        rule: RecurrenceRule,
        anchor: GameDay,
        calendar: GameCalendar,
        state: RecurringPeriodState,
        remaining: Int,
        completedToday: Int,
        maxPerDay: Int,
        pausedDayValues: Set<Int>
    ) -> Bool {
        guard remaining > 0 else { return false }
        guard !pausedDayValues.contains(day.value) else { return false }
        guard completedToday < max(1, maxPerDay) else { return false }
        if state == .grace { return true }
        return ScheduleEngine.occurs(rule: rule, on: day, anchor: anchor, calendar: calendar)
    }

    static func shouldFailSingle(
        scheduledDay: GameDay,
        dueDay: GameDay?,
        today: GameDay,
        calendar: GameCalendar,
        pausedDayValues: Set<Int>
    ) -> Bool {
        let origin = dueDay ?? scheduledDay
        guard today > origin else { return false }
        return activeDaysBetween(origin, today, calendar: calendar, pausedDayValues: pausedDayValues)
            > singleFailAfterActiveDays
    }
}
