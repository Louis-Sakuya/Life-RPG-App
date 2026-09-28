import XCTest
@testable import LifeRPG

final class RecurringFinishEngineTests: XCTestCase {

    private var calendar: GameCalendar {
        var base = Calendar(identifier: .gregorian)
        base.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return GameCalendar(dayStartHour: 4, calendar: base)
    }

    func testDurationIsInclusive() {
        let start = GameDay(year: 2026, month: 8, day: 1)
        let end = GameDay(year: 2026, month: 8, day: 30)
        XCTAssertEqual(
            RecurringFinishEngine.durationDays(from: start, to: end, calendar: calendar),
            30
        )
    }

    func testSameDayCountsAsOne() {
        let day = GameDay(year: 2026, month: 8, day: 23)
        XCTAssertEqual(
            RecurringFinishEngine.durationDays(from: day, to: day, calendar: calendar),
            1
        )
    }

    func testFutureStartFallsBackToOneDay() {
        let start = GameDay(year: 2026, month: 9, day: 1)
        let today = GameDay(year: 2026, month: 8, day: 23)
        XCTAssertEqual(
            RecurringFinishEngine.durationDays(from: start, to: today, calendar: calendar),
            1
        )
    }

    func testRewardScalesWithDurationAndMilestones() {
        let day1 = RecurringFinishEngine.evaluate(durationDays: 1, completions: 1)
        let day30 = RecurringFinishEngine.evaluate(durationDays: 30, completions: 25)
        let day100 = RecurringFinishEngine.evaluate(durationDays: 100, completions: 80)
        let day365 = RecurringFinishEngine.evaluate(durationDays: 365, completions: 300)

        XCTAssertEqual(day1.tier, .spark)
        XCTAssertEqual(day30.tier, .veteran)
        XCTAssertEqual(day100.tier, .legendary)
        XCTAssertEqual(day365.tier, .mythic)

        XCTAssertGreaterThan(day30.exp, day1.exp)
        XCTAssertGreaterThan(day100.exp, day30.exp)
        XCTAssertGreaterThan(day365.exp, day100.exp)
        XCTAssertGreaterThan(day365.exp, 10_000)
        XCTAssertEqual(day1.gold, Int((Double(day1.exp) * 0.9).rounded()))
    }

    func testCompletionBonusIsCappedByDuration() {
        let modest = RecurringFinishEngine.evaluate(durationDays: 10, completions: 20)
        let flooded = RecurringFinishEngine.evaluate(durationDays: 10, completions: 10_000)
        XCTAssertEqual(modest.exp, flooded.exp)
    }
}
