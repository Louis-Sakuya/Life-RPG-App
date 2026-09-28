import Foundation

/// 周期任务的排期判定。新增重复规律时，这里是唯一需要改动的地方，
/// 下游系统只消费生成出来的 `Quest` 实例，因此不受影响。
enum ScheduleEngine {

    /// 起算日。"从下周开始"的语义按规律的周期粒度解释：
    /// 周规律推到下周一，月规律推到下月一号，日规律推到明天。
    static func effectiveStartDay(
        rule: RecurrenceRule,
        startDay: GameDay,
        policy: RecurrenceStartPolicy,
        calendar: GameCalendar
    ) -> GameDay {
        guard policy == .nextPeriod else { return startDay }
        switch rule {
        case .daily:
            return calendar.adding(days: 1, to: startDay)
        case .weekly, .timesPerWeek:
            return calendar.adding(days: 7, to: startDay)
        case .monthly:
            let nextMonthMonth = startDay.month == 12 ? 1 : startDay.month + 1
            let nextMonthYear = startDay.month == 12 ? startDay.year + 1 : startDay.year
            return GameDay(year: nextMonthYear, month: nextMonthMonth, day: 1)
        }
    }

    static func occurs(
        rule: RecurrenceRule,
        on day: GameDay,
        anchor: GameDay,
        calendar: GameCalendar
    ) -> Bool {
        guard day >= anchor else { return false }
        switch rule {
        case .daily(let interval):
            let step = max(1, interval)
            return calendar.daysBetween(anchor, day) % step == 0

        case .weekly(let weekdays):
            guard !weekdays.isEmpty else { return false }
            return weekdays.contains(calendar.weekday(of: day))

        case .timesPerWeek:
            // 每周 n 次是配额，不绑死具体星期。能否再完成一次由每日上限与剩余次数决定。
            return true

        case .monthly(let days):
            guard !days.isEmpty else { return false }
            return days.contains(day.day)
        }
    }

    /// 列出区间内所有应当生成实例的日子
    static func occurrences(
        rule: RecurrenceRule,
        in range: ClosedRange<GameDay>,
        anchor: GameDay,
        calendar: GameCalendar
    ) -> [GameDay] {
        calendar.days(from: range.lowerBound, through: range.upperBound)
            .filter { occurs(rule: rule, on: $0, anchor: anchor, calendar: calendar) }
    }
}
