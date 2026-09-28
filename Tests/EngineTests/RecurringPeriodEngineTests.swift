import XCTest
@testable import LifeRPG

final class RecurringPeriodEngineTests: XCTestCase {

    private var calendar: GameCalendar {
        var base = Calendar(identifier: .gregorian)
        base.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return GameCalendar(dayStartHour: 4, calendar: base)
    }

    /// 2026-08-05 周三
    private let wednesday = GameDay(year: 2026, month: 8, day: 5)
    private let thursday = GameDay(year: 2026, month: 8, day: 6)
    private let nextWednesday = GameDay(year: 2026, month: 8, day: 12)
    private let nextThursday = GameDay(year: 2026, month: 8, day: 13)

    func testRollingWindowLastsSevenActiveDays() {
        let last = RecurringPeriodEngine.lastDayOfWindow(
            start: wednesday,
            calendar: calendar,
            pausedDayValues: []
        )
        XCTAssertEqual(last, GameDay(year: 2026, month: 8, day: 11))
        XCTAssertFalse(
            RecurringPeriodEngine.windowHasEnded(
                start: wednesday,
                on: last,
                calendar: calendar,
                pausedDayValues: []
            )
        )
        XCTAssertTrue(
            RecurringPeriodEngine.windowHasEnded(
                start: wednesday,
                on: nextWednesday,
                calendar: calendar,
                pausedDayValues: []
            )
        )
    }

    func testPausedDayExtendsWindowSoNextWednesdayDoesNotEndIt() {
        let tuesday = GameDay(year: 2026, month: 8, day: 11)
        let last = RecurringPeriodEngine.lastDayOfWindow(
            start: wednesday,
            calendar: calendar,
            pausedDayValues: [tuesday.value]
        )
        XCTAssertEqual(last, nextWednesday)
        XCTAssertFalse(
            RecurringPeriodEngine.windowHasEnded(
                start: wednesday,
                on: nextWednesday,
                calendar: calendar,
                pausedDayValues: [tuesday.value]
            )
        )
        XCTAssertTrue(
            RecurringPeriodEngine.windowHasEnded(
                start: wednesday,
                on: nextThursday,
                calendar: calendar,
                pausedDayValues: [tuesday.value]
            )
        )
    }

    func testTimesPerWeekQuotaIgnoresDailyCapExceptAsUpperBound() {
        let quota = RecurringPeriodEngine.periodQuota(
            rule: .timesPerWeek(count: 2),
            maxPerDay: 1,
            periodStart: wednesday,
            anchor: wednesday,
            calendar: calendar,
            pausedDayValues: []
        )
        XCTAssertEqual(quota, 2)
    }

    func testWeeklyQuotaIsSelectedWeekdayCount() {
        let quota = RecurringPeriodEngine.periodQuota(
            rule: .weekly(weekdays: [4, 6]),
            maxPerDay: 3,
            periodStart: wednesday,
            anchor: wednesday,
            calendar: calendar,
            pausedDayValues: []
        )
        XCTAssertEqual(quota, 2)
    }

    func testDailyQuotaCountsOccurrencesTimesDailyCap() {
        let quota = RecurringPeriodEngine.periodQuota(
            rule: .daily(interval: 1),
            maxPerDay: 2,
            periodStart: wednesday,
            anchor: wednesday,
            calendar: calendar,
            pausedDayValues: []
        )
        XCTAssertEqual(quota, 14)
    }

    func testRemainingNeverGoesNegative() {
        XCTAssertEqual(RecurringPeriodEngine.remaining(quota: 2, completed: 5), 0)
        XCTAssertEqual(RecurringPeriodEngine.remaining(quota: 3, completed: 1), 2)
    }

    func testDailyCapBlocksFurtherCompletions() {
        let allowed = RecurringPeriodEngine.canComplete(
            on: wednesday,
            rule: .timesPerWeek(count: 3),
            anchor: wednesday,
            calendar: calendar,
            state: .active,
            remaining: 2,
            completedToday: 1,
            maxPerDay: 1,
            pausedDayValues: []
        )
        XCTAssertFalse(allowed)
    }

    func testGraceAllowsAnyNonPausedDay() {
        let friday = GameDay(year: 2026, month: 8, day: 7)
        let allowed = RecurringPeriodEngine.canComplete(
            on: friday,
            rule: .weekly(weekdays: [4]),
            anchor: wednesday,
            calendar: calendar,
            state: .grace,
            remaining: 1,
            completedToday: 0,
            maxPerDay: 1,
            pausedDayValues: []
        )
        XCTAssertTrue(allowed)
    }

    func testSingleFailsAfterMoreThanThreeActiveDays() {
        let monday = GameDay(year: 2026, month: 8, day: 3)
        XCTAssertFalse(
            RecurringPeriodEngine.shouldFailSingle(
                scheduledDay: monday,
                dueDay: nil,
                today: GameDay(year: 2026, month: 8, day: 6),
                calendar: calendar,
                pausedDayValues: []
            )
        )
        XCTAssertTrue(
            RecurringPeriodEngine.shouldFailSingle(
                scheduledDay: monday,
                dueDay: nil,
                today: GameDay(year: 2026, month: 8, day: 7),
                calendar: calendar,
                pausedDayValues: []
            )
        )
    }

    func testPausedDayDoesNotCountTowardSingleFailClock() {
        let monday = GameDay(year: 2026, month: 8, day: 3)
        let friday = GameDay(year: 2026, month: 8, day: 7)
        XCTAssertFalse(
            RecurringPeriodEngine.shouldFailSingle(
                scheduledDay: monday,
                dueDay: nil,
                today: friday,
                calendar: calendar,
                pausedDayValues: [GameDay(year: 2026, month: 8, day: 5).value]
            )
        )
    }
}
