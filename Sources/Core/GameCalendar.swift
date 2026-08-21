import Foundation

/// 全 App 唯一的时间源。业务代码不得直接用 `Calendar` 或 `Date()` 判断"今天"，
/// 否则连续天数与每日结算一定会在跨零点、跨时区的场景下出错。
struct GameCalendar: Sendable {
    /// 一天的起始时刻（0...23）。默认 4 表示凌晨 4 点前仍算作前一天，
    /// 这样夜猫子在 1 点完成的任务会正确计入前一天的打卡与统计。
    var dayStartHour: Int
    var calendar: Calendar

    init(dayStartHour: Int = 4, calendar: Calendar = .current) {
        self.dayStartHour = max(0, min(23, dayStartHour))
        self.calendar = calendar
    }

    // MARK: - Date <-> GameDay

    func gameDay(for date: Date) -> GameDay {
        let shifted = calendar.date(byAdding: .hour, value: -dayStartHour, to: date) ?? date
        let comps = calendar.dateComponents([.year, .month, .day], from: shifted)
        return GameDay(year: comps.year ?? 1970, month: comps.month ?? 1, day: comps.day ?? 1)
    }

    var today: GameDay { gameDay(for: Date()) }

    /// 该游戏日的真实起始时刻
    func startDate(of day: GameDay) -> Date {
        var comps = day.dateComponents
        comps.hour = dayStartHour
        return calendar.date(from: comps) ?? Date()
    }

    /// 该游戏日的真实结束时刻（不含）
    func endDate(of day: GameDay) -> Date {
        calendar.date(byAdding: .day, value: 1, to: startDate(of: day)) ?? Date()
    }

    /// 日历意义上的当天午夜，用于展示与日期选择器。
    /// 与 `gameDay(fromDisplayDate:)` 成对：选「21 号」必须还原成 21 号，不能再走日界线。
    func displayDate(of day: GameDay) -> Date {
        calendar.date(from: day.dateComponents) ?? Date()
    }

    /// 把日期选择器的日历日还原成 `GameDay`。
    ///
    /// `DatePicker(.date)` 给出的是当天午夜。若误用 `gameDay(for:)`，会按 `dayStartHour`
    /// 把 21 号 00:00 算成 20 号，紧急任务会被当成「当天临时」吃 -50%。
    func gameDay(fromDisplayDate date: Date) -> GameDay {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return GameDay(year: comps.year ?? 1970, month: comps.month ?? 1, day: comps.day ?? 1)
    }

    /// 把某个钟点落到指定游戏日的墙上时间，用于"当天 21:00 截止"。
    func date(on day: GameDay, hour: Int, minute: Int, second: Int = 0) -> Date {
        var comps = day.dateComponents
        comps.hour = hour
        comps.minute = minute
        comps.second = second
        return calendar.date(from: comps) ?? displayDate(of: day)
    }

    func date(on day: GameDay, matchingTimeOf timeSource: Date) -> Date {
        date(
            on: day,
            hour: calendar.component(.hour, from: timeSource),
            minute: calendar.component(.minute, from: timeSource)
        )
    }

    // MARK: - 日期运算

    func adding(days: Int, to day: GameDay) -> GameDay {
        guard days != 0 else { return day }
        let base = displayDate(of: day)
        guard let moved = calendar.date(byAdding: .day, value: days, to: base) else { return day }
        let comps = calendar.dateComponents([.year, .month, .day], from: moved)
        return GameDay(year: comps.year ?? day.year, month: comps.month ?? day.month, day: comps.day ?? day.day)
    }

    func daysBetween(_ from: GameDay, _ to: GameDay) -> Int {
        let a = displayDate(of: from)
        let b = displayDate(of: to)
        return calendar.dateComponents([.day], from: a, to: b).day ?? 0
    }

    /// 闭区间的游戏日序列，用于每日结算的逐日补算
    func days(from: GameDay, through: GameDay) -> [GameDay] {
        guard from <= through else { return [] }
        var result: [GameDay] = []
        var cursor = from
        while cursor <= through {
            result.append(cursor)
            cursor = adding(days: 1, to: cursor)
        }
        return result
    }

    // MARK: - 周 / 月

    /// 1 = 周日 ... 7 = 周六，与 `Calendar.component(.weekday:)` 一致
    func weekday(of day: GameDay) -> Int {
        calendar.component(.weekday, from: displayDate(of: day))
    }

    /// 周一为一周的第一天，返回该周的周一
    func startOfWeek(for day: GameDay) -> GameDay {
        let weekdayIndex = weekday(of: day)
        let offset = (weekdayIndex + 5) % 7
        return adding(days: -offset, to: day)
    }

    func startOfMonth(for day: GameDay) -> GameDay {
        GameDay(year: day.year, month: day.month, day: 1)
    }

    func startOfYear(for day: GameDay) -> GameDay {
        GameDay(year: day.year, month: 1, day: 1)
    }

    /// 完成时刻在游戏日内的"逻辑小时"。跨过午夜的部分会返回 24...27，
    /// 这样"凌晨 1 点完成任务"可以用 `hour >= 25` 这样的阈值直接描述。
    func logicalHour(of date: Date) -> Int {
        let hour = calendar.component(.hour, from: date)
        return hour < dayStartHour ? hour + 24 : hour
    }
}
