import XCTest
@testable import LifeRPG

final class StreakEngineTests: XCTestCase {

    private let calendar = GameCalendar(dayStartHour: 4, calendar: Calendar(identifier: .gregorian))
    private let day1 = GameDay(year: 2026, month: 8, day: 1)
    private let day2 = GameDay(year: 2026, month: 8, day: 2)
    private let day3 = GameDay(year: 2026, month: 8, day: 3)
    private let day10 = GameDay(year: 2026, month: 8, day: 10)

    func testFirstAdvanceStartsAtOne() {
        let state = StreakEngine.advance(.empty, on: day1, calendar: calendar)
        XCTAssertEqual(state.current, 1)
        XCTAssertEqual(state.best, 1)
        XCTAssertEqual(state.lastDay, day1)
    }

    func testConsecutiveDaysAccumulate() {
        var state = StreakEngine.advance(.empty, on: day1, calendar: calendar)
        state = StreakEngine.advance(state, on: day2, calendar: calendar)
        state = StreakEngine.advance(state, on: day3, calendar: calendar)
        XCTAssertEqual(state.current, 3)
        XCTAssertEqual(state.best, 3)
    }

    /// 同一天重复打卡不应该刷连续数，否则玩家点两下就能刷满
    func testSameDayAdvanceIsIdempotent() {
        var state = StreakEngine.advance(.empty, on: day1, calendar: calendar)
        state = StreakEngine.advance(state, on: day1, calendar: calendar)
        state = StreakEngine.advance(state, on: day1, calendar: calendar)
        XCTAssertEqual(state.current, 1)
    }

    func testGapResetsCurrentButKeepsBest() {
        var state = StreakEngine.advance(.empty, on: day1, calendar: calendar)
        state = StreakEngine.advance(state, on: day2, calendar: calendar)
        state = StreakEngine.advance(state, on: day3, calendar: calendar)
        state = StreakEngine.advance(state, on: day10, calendar: calendar)
        XCTAssertEqual(state.current, 1)
        XCTAssertEqual(state.best, 3)
    }

    func testBackfillDoesNotChangeCurrent() {
        var state = StreakEngine.advance(.empty, on: day3, calendar: calendar)
        state = StreakEngine.advance(state, on: day1, calendar: calendar)
        XCTAssertEqual(state.current, 1)
        XCTAssertEqual(state.lastDay, day3)
    }

    /// 每日结算时必须把早已断掉的连续清零，否则界面会一直显示一个虚高的数字
    func testDecayClearsBrokenStreak() {
        var state = StreakEngine.advance(.empty, on: day1, calendar: calendar)
        state = StreakEngine.advance(state, on: day2, calendar: calendar)
        let decayed = StreakEngine.decayIfBroken(state, today: day10, calendar: calendar)
        XCTAssertEqual(decayed.current, 0)
        XCTAssertEqual(decayed.best, 2)
    }

    func testDecayKeepsStreakOnConsecutiveDay() {
        let state = StreakEngine.advance(.empty, on: day1, calendar: calendar)
        let decayed = StreakEngine.decayIfBroken(state, today: day2, calendar: calendar)
        XCTAssertEqual(decayed.current, 1)
    }

    func testDecayKeepsStreakOnSameDay() {
        let state = StreakEngine.advance(.empty, on: day1, calendar: calendar)
        let decayed = StreakEngine.decayIfBroken(state, today: day1, calendar: calendar)
        XCTAssertEqual(decayed.current, 1)
    }

    func testRevertUndoesLastDay() {
        var state = StreakEngine.advance(.empty, on: day1, calendar: calendar)
        state = StreakEngine.advance(state, on: day2, calendar: calendar)
        let reverted = StreakEngine.revert(state, on: day2, calendar: calendar)
        XCTAssertEqual(reverted.current, 1)
        XCTAssertEqual(reverted.lastDay, day1)
        XCTAssertEqual(reverted.best, 2)
    }

    func testRevertOfOlderDayIsNoop() {
        var state = StreakEngine.advance(.empty, on: day1, calendar: calendar)
        state = StreakEngine.advance(state, on: day2, calendar: calendar)
        let reverted = StreakEngine.revert(state, on: day1, calendar: calendar)
        XCTAssertEqual(reverted.current, 2)
    }

    func testNextTierPointsAtTheUpcomingGoal() {
        let tiers = BalanceConfig.fallback.streakTiers
        XCTAssertEqual(StreakEngine.nextTier(forDays: 0, tiers: tiers)?.days, 7)
        XCTAssertEqual(StreakEngine.nextTier(forDays: 7, tiers: tiers)?.days, 30)
        XCTAssertNil(StreakEngine.nextTier(forDays: 100, tiers: tiers))
    }
}
