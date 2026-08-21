import XCTest
@testable import LifeRPG

final class LuckyEngineTests: XCTestCase {

    private let config = FortuneConfig.fallback

    func testGrowthSucceedsBelowChance() {
        XCTAssertTrue(LuckyEngine.succeeds(roll: 0.001, chance: 0.002))
        XCTAssertFalse(LuckyEngine.succeeds(roll: 0.002, chance: 0.002))
        XCTAssertFalse(LuckyEngine.succeeds(roll: 0.5, chance: 0.002))
    }

    func testZeroChanceNeverSucceeds() {
        XCTAssertFalse(LuckyEngine.succeeds(roll: 0, chance: 0))
    }

    func testLuckyDayChanceScalesWithLevelAndClamps() {
        let level1 = LuckyEngine.luckyDayChance(luckyLevel: 1, config: config)
        let level5 = LuckyEngine.luckyDayChance(luckyLevel: 5, config: config)
        XCTAssertEqual(level1, config.luckyDay.baseChance, accuracy: 0.0001)
        XCTAssertGreaterThan(level5, level1)
        let huge = LuckyEngine.luckyDayChance(luckyLevel: 1000, config: config)
        XCTAssertEqual(huge, config.luckyDay.maxChance, accuracy: 0.0001)
    }

    func testFortunePickFollowsWeights() {
        let fortunes = config.fortunes
        XCTAssertEqual(LuckyEngine.pickFortune(roll: 0, fortunes: fortunes)?.id, "fortune_1")
        XCTAssertEqual(LuckyEngine.pickFortune(roll: 0.99, fortunes: fortunes)?.id, "fortune_4")
    }

    func testEmptyFortunesReturnNil() {
        XCTAssertNil(LuckyEngine.pickFortune(roll: 0.5, fortunes: []))
    }
}
