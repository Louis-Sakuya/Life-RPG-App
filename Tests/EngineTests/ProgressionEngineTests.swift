import XCTest
@testable import LifeRPG

final class ProgressionEngineTests: XCTestCase {

    func testLevelOneHasNoBonus() {
        XCTAssertEqual(ProgressionEngine.bonus(level: 1, perLevel: 0.03, cap: 2.5), 1, accuracy: 0.0001)
        XCTAssertEqual(ProgressionEngine.bonus(level: 0, perLevel: 0.03, cap: 2.5), 1, accuracy: 0.0001)
    }

    func testBonusScalesThenClamps() {
        XCTAssertEqual(ProgressionEngine.bonus(level: 11, perLevel: 0.03, cap: 2.5), 1.3, accuracy: 0.0001)
        XCTAssertEqual(ProgressionEngine.bonus(level: 100, perLevel: 0.03, cap: 2.5), 2.5, accuracy: 0.0001)
    }

    func testQuestRewardUsesWeightedSkillLevels() {
        let low = UUID()
        let high = UUID()
        let multiplier = ProgressionEngine.questRewardMultiplier(
            shares: [
                SkillShare(skillID: low, expShare: 0.5),
                SkillShare(skillID: high, expShare: 0.5)
            ],
            levels: [low: 1, high: 11],
            perLevel: 0.02,
            cap: 2.0
        )
        // (1.0 + 1.2) / 2 = 1.1
        XCTAssertEqual(multiplier, 1.1, accuracy: 0.0001)
    }

    func testQuestRewardWithoutSharesIsNeutral() {
        XCTAssertEqual(
            ProgressionEngine.questRewardMultiplier(shares: [], levels: [:], perLevel: 0.02, cap: 2),
            1,
            accuracy: 0.0001
        )
    }

    func testSkillXPUsesWeightedStats() {
        let multiplier = ProgressionEngine.skillXPMultiplier(
            affinities: [
                StatAffinity(stat: .body, weight: 0.7),
                StatAffinity(stat: .life, weight: 0.3)
            ],
            statLevels: [.body: 11, .life: 1],
            perLevel: 0.03,
            cap: 2.5
        )
        // 0.7 * 1.3 + 0.3 * 1.0 = 1.21
        XCTAssertEqual(multiplier, 1.21, accuracy: 0.0001)
    }

    func testSkillXPWithoutAffinitiesIsNeutral() {
        XCTAssertEqual(
            ProgressionEngine.skillXPMultiplier(affinities: [], statLevels: [.mind: 50], perLevel: 0.03, cap: 2.5),
            1,
            accuracy: 0.0001
        )
    }
}
