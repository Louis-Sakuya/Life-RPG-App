import XCTest
@testable import LifeRPG

final class ScheduleEngineTests: XCTestCase {

    private var calendar: GameCalendar {
        var base = Calendar(identifier: .gregorian)
        base.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return GameCalendar(dayStartHour: 4, calendar: base)
    }

    // 2026-08-03 是周一
    private let monday = GameDay(year: 2026, month: 8, day: 3)
    private let tuesday = GameDay(year: 2026, month: 8, day: 4)
    private let wednesday = GameDay(year: 2026, month: 8, day: 5)
    private let sunday = GameDay(year: 2026, month: 8, day: 9)

    func testDailyEveryDay() {
        let rule = RecurrenceRule.daily(interval: 1)
        for offset in 0...10 {
            let day = calendar.adding(days: offset, to: monday)
            XCTAssertTrue(ScheduleEngine.occurs(rule: rule, on: day, anchor: monday, calendar: calendar))
        }
    }

    func testDailyWithInterval() {
        let rule = RecurrenceRule.daily(interval: 3)
        XCTAssertTrue(ScheduleEngine.occurs(rule: rule, on: monday, anchor: monday, calendar: calendar))
        XCTAssertFalse(ScheduleEngine.occurs(rule: rule, on: tuesday, anchor: monday, calendar: calendar))
        XCTAssertFalse(ScheduleEngine.occurs(rule: rule, on: wednesday, anchor: monday, calendar: calendar))
        XCTAssertTrue(ScheduleEngine.occurs(rule: rule, on: calendar.adding(days: 3, to: monday), anchor: monday, calendar: calendar))
    }

    func testNothingOccursBeforeAnchor() {
        let rule = RecurrenceRule.daily(interval: 1)
        let beforeAnchor = calendar.adding(days: -1, to: monday)
        XCTAssertFalse(ScheduleEngine.occurs(rule: rule, on: beforeAnchor, anchor: monday, calendar: calendar))
    }

    func testWeeklyMatchesSelectedWeekdays() {
        // 3 = 周二，5 = 周四
        let rule = RecurrenceRule.weekly(weekdays: [3, 5])
        XCTAssertFalse(ScheduleEngine.occurs(rule: rule, on: monday, anchor: monday, calendar: calendar))
        XCTAssertTrue(ScheduleEngine.occurs(rule: rule, on: tuesday, anchor: monday, calendar: calendar))
        XCTAssertFalse(ScheduleEngine.occurs(rule: rule, on: wednesday, anchor: monday, calendar: calendar))
    }

    /// "每周 3 次"必须是确定性的，否则补算与重装应用会生成不同的日程
    func testTimesPerWeekIsDeterministic() {
        let rule = RecurrenceRule.timesPerWeek(count: 3)
        XCTAssertTrue(ScheduleEngine.occurs(rule: rule, on: monday, anchor: monday, calendar: calendar))
        XCTAssertTrue(ScheduleEngine.occurs(rule: rule, on: tuesday, anchor: monday, calendar: calendar))
        XCTAssertTrue(ScheduleEngine.occurs(rule: rule, on: wednesday, anchor: monday, calendar: calendar))
        XCTAssertFalse(ScheduleEngine.occurs(rule: rule, on: calendar.adding(days: 3, to: monday), anchor: monday, calendar: calendar))
        XCTAssertFalse(ScheduleEngine.occurs(rule: rule, on: sunday, anchor: monday, calendar: calendar))
    }

    func testTimesPerWeekProducesExactCountPerWeek() {
        let rule = RecurrenceRule.timesPerWeek(count: 3)
        let range = monday...calendar.adding(days: 6, to: monday)
        let occurrences = ScheduleEngine.occurrences(rule: rule, in: range, anchor: monday, calendar: calendar)
        XCTAssertEqual(occurrences.count, 3)
    }

    func testMonthlyMatchesDayOfMonth() {
        let rule = RecurrenceRule.monthly(days: [1, 15])
        XCTAssertFalse(ScheduleEngine.occurs(rule: rule, on: monday, anchor: monday, calendar: calendar))
        let fifteenth = GameDay(year: 2026, month: 8, day: 15)
        XCTAssertTrue(ScheduleEngine.occurs(rule: rule, on: fifteenth, anchor: monday, calendar: calendar))
    }

    // MARK: - 起算策略

    func testThisPeriodKeepsStartDay() {
        let start = ScheduleEngine.effectiveStartDay(
            rule: .weekly(weekdays: [2]),
            startDay: wednesday,
            policy: .thisPeriod,
            calendar: calendar
        )
        XCTAssertEqual(start, wednesday)
    }

    func testNextPeriodPushesWeeklyToNextMonday() {
        let start = ScheduleEngine.effectiveStartDay(
            rule: .weekly(weekdays: [2]),
            startDay: wednesday,
            policy: .nextPeriod,
            calendar: calendar
        )
        XCTAssertEqual(start, GameDay(year: 2026, month: 8, day: 10))
    }

    func testNextPeriodPushesMonthlyToFirstOfNextMonth() {
        let start = ScheduleEngine.effectiveStartDay(
            rule: .monthly(days: [1]),
            startDay: wednesday,
            policy: .nextPeriod,
            calendar: calendar
        )
        XCTAssertEqual(start, GameDay(year: 2026, month: 9, day: 1))
    }

    func testNextPeriodRollsOverYearForMonthly() {
        let start = ScheduleEngine.effectiveStartDay(
            rule: .monthly(days: [1]),
            startDay: GameDay(year: 2026, month: 12, day: 20),
            policy: .nextPeriod,
            calendar: calendar
        )
        XCTAssertEqual(start, GameDay(year: 2027, month: 1, day: 1))
    }

    func testNextPeriodPushesDailyToTomorrow() {
        let start = ScheduleEngine.effectiveStartDay(
            rule: .daily(interval: 1),
            startDay: wednesday,
            policy: .nextPeriod,
            calendar: calendar
        )
        XCTAssertEqual(start, GameDay(year: 2026, month: 8, day: 6))
    }
}
