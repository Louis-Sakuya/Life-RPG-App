import XCTest
@testable import LifeRPG

final class GameCalendarTests: XCTestCase {

    private var baseCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    private func makeCalendar(dayStartHour: Int = 4) -> GameCalendar {
        GameCalendar(dayStartHour: dayStartHour, calendar: baseCalendar)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return baseCalendar.date(from: components) ?? Date()
    }

    // MARK: - 游戏日边界

    /// 这是整个应用最容易出错的地方：夜猫子在凌晨完成的任务必须算作前一天，
    /// 否则连续天数会在用户没有中断的情况下断掉
    func testAfterMidnightBelongsToPreviousDay() {
        let calendar = makeCalendar(dayStartHour: 4)
        XCTAssertEqual(calendar.gameDay(for: date(2026, 8, 4, 1, 30)), GameDay(year: 2026, month: 8, day: 3))
        XCTAssertEqual(calendar.gameDay(for: date(2026, 8, 4, 3, 59)), GameDay(year: 2026, month: 8, day: 3))
    }

    func testAfterDayStartBelongsToCurrentDay() {
        let calendar = makeCalendar(dayStartHour: 4)
        XCTAssertEqual(calendar.gameDay(for: date(2026, 8, 4, 4, 0)), GameDay(year: 2026, month: 8, day: 4))
        XCTAssertEqual(calendar.gameDay(for: date(2026, 8, 4, 23, 59)), GameDay(year: 2026, month: 8, day: 4))
    }

    func testMidnightStartHourBehavesLikePlainCalendar() {
        let calendar = makeCalendar(dayStartHour: 0)
        XCTAssertEqual(calendar.gameDay(for: date(2026, 8, 4, 0, 5)), GameDay(year: 2026, month: 8, day: 4))
    }

    func testDayStartHourIsClamped() {
        XCTAssertEqual(GameCalendar(dayStartHour: -5).dayStartHour, 0)
        XCTAssertEqual(GameCalendar(dayStartHour: 99).dayStartHour, 23)
    }

    // MARK: - 逻辑小时

    /// "凌晨 1 点完成任务"这类成就条件用 hour >= 25 描述，因此跨午夜后必须继续往上加
    func testLogicalHourExtendsPastMidnight() {
        let calendar = makeCalendar(dayStartHour: 4)
        XCTAssertEqual(calendar.logicalHour(of: date(2026, 8, 4, 5, 0)), 5)
        XCTAssertEqual(calendar.logicalHour(of: date(2026, 8, 4, 23, 0)), 23)
        XCTAssertEqual(calendar.logicalHour(of: date(2026, 8, 4, 1, 0)), 25)
        XCTAssertEqual(calendar.logicalHour(of: date(2026, 8, 4, 3, 0)), 27)
    }

    // MARK: - 日期运算

    func testAddingDaysCrossesMonthBoundary() {
        let calendar = makeCalendar()
        let lastOfJuly = GameDay(year: 2026, month: 7, day: 31)
        XCTAssertEqual(calendar.adding(days: 1, to: lastOfJuly), GameDay(year: 2026, month: 8, day: 1))
        XCTAssertEqual(calendar.adding(days: -1, to: GameDay(year: 2026, month: 8, day: 1)), lastOfJuly)
    }

    func testAddingDaysCrossesYearBoundary() {
        let calendar = makeCalendar()
        let newYearsEve = GameDay(year: 2026, month: 12, day: 31)
        XCTAssertEqual(calendar.adding(days: 1, to: newYearsEve), GameDay(year: 2027, month: 1, day: 1))
    }

    func testDaysBetweenHandlesLeapYear() {
        let calendar = makeCalendar()
        let feb28 = GameDay(year: 2028, month: 2, day: 28)
        let mar1 = GameDay(year: 2028, month: 3, day: 1)
        XCTAssertEqual(calendar.daysBetween(feb28, mar1), 2)
    }

    func testDaySequenceIsInclusive() {
        let calendar = makeCalendar()
        let from = GameDay(year: 2026, month: 8, day: 1)
        let through = GameDay(year: 2026, month: 8, day: 5)
        let days = calendar.days(from: from, through: through)
        XCTAssertEqual(days.count, 5)
        XCTAssertEqual(days.first, from)
        XCTAssertEqual(days.last, through)
    }

    func testDaySequenceIsEmptyWhenReversed() {
        let calendar = makeCalendar()
        let days = calendar.days(
            from: GameDay(year: 2026, month: 8, day: 5),
            through: GameDay(year: 2026, month: 8, day: 1)
        )
        XCTAssertTrue(days.isEmpty)
    }

    // MARK: - 周

    func testStartOfWeekIsMonday() {
        let calendar = makeCalendar()
        // 2026-08-04 是周二
        let tuesday = GameDay(year: 2026, month: 8, day: 4)
        XCTAssertEqual(calendar.startOfWeek(for: tuesday), GameDay(year: 2026, month: 8, day: 3))
    }

    func testSundayBelongsToPreviousMondayWeek() {
        let calendar = makeCalendar()
        // 2026-08-09 是周日，应当归属 08-03 那一周
        let sunday = GameDay(year: 2026, month: 8, day: 9)
        XCTAssertEqual(calendar.startOfWeek(for: sunday), GameDay(year: 2026, month: 8, day: 3))
    }

    // MARK: - GameDay 值语义

    func testGameDayOrdersChronologically() {
        XCTAssertLessThan(GameDay(year: 2026, month: 8, day: 4), GameDay(year: 2026, month: 8, day: 5))
        XCTAssertLessThan(GameDay(year: 2026, month: 8, day: 31), GameDay(year: 2026, month: 9, day: 1))
        XCTAssertLessThan(GameDay(year: 2026, month: 12, day: 31), GameDay(year: 2027, month: 1, day: 1))
    }

    func testDateOnDayKeepsWallClockTime() {
        let calendar = makeCalendar(dayStartHour: 4)
        let day = GameDay(year: 2026, month: 8, day: 4)
        let due = calendar.date(on: day, hour: 21, minute: 30)
        XCTAssertEqual(calendar.gameDay(for: due), day)
        XCTAssertEqual(baseCalendar.component(.hour, from: due), 21)
        XCTAssertEqual(baseCalendar.component(.minute, from: due), 30)
    }

    func testDateMatchingTimeOfUsesSourceClock() {
        let calendar = makeCalendar()
        let source = date(2026, 1, 1, 18, 45)
        let due = calendar.date(on: GameDay(year: 2026, month: 8, day: 20), matchingTimeOf: source)
        XCTAssertEqual(baseCalendar.component(.hour, from: due), 18)
        XCTAssertEqual(baseCalendar.component(.minute, from: due), 45)
        XCTAssertEqual(baseCalendar.component(.month, from: due), 8)
        XCTAssertEqual(baseCalendar.component(.day, from: due), 20)
    }

    func testGameDayRoundTripsThroughRawValue() {
        let day = GameDay(year: 2026, month: 8, day: 4)
        XCTAssertEqual(day.value, 20_260_804)
        let restored = GameDay(value: day.value)
        XCTAssertEqual(restored.year, 2026)
        XCTAssertEqual(restored.month, 8)
        XCTAssertEqual(restored.day, 4)
    }

    // MARK: - 日期选择器

    /// DatePicker 给出的是日历日午夜。走 `gameDay(for:)` 会被 dayStartHour 回退一天，
    /// 必须用 `gameDay(fromDisplayDate:)` 才能让「选 21 号」真的落在 21 号。
    func testDisplayDateRoundTripIgnoresDayStartHour() {
        let calendar = makeCalendar(dayStartHour: 4)
        let picked = GameDay(year: 2026, month: 8, day: 21)
        let displayed = calendar.displayDate(of: picked)

        XCTAssertEqual(calendar.gameDay(fromDisplayDate: displayed), picked)
        XCTAssertEqual(calendar.gameDay(for: displayed), GameDay(year: 2026, month: 8, day: 20))
    }

    func testPickingTomorrowIsPlannedAhead() {
        let calendar = makeCalendar(dayStartHour: 4)
        let today = GameDay(year: 2026, month: 8, day: 20)
        let tomorrow = calendar.adding(days: 1, to: today)
        let picked = calendar.gameDay(fromDisplayDate: calendar.displayDate(of: tomorrow))

        XCTAssertEqual(picked, tomorrow)
        XCTAssertGreaterThan(picked, today)
        XCTAssertEqual(calendar.gameDay(for: calendar.displayDate(of: tomorrow)), today)
    }
}
