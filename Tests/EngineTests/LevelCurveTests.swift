import XCTest
@testable import LifeRPG

final class LevelCurveTests: XCTestCase {

    private let curve = LevelCurve(config: .init(base: 100, exponent: 1.5, maxLevel: 100))

    func testStartsAtLevelOne() {
        let progress = curve.progress(totalEXP: 0)
        XCTAssertEqual(progress.level, 1)
        XCTAssertEqual(progress.currentEXP, 0)
        XCTAssertEqual(progress.requiredEXP, 100)
        XCTAssertEqual(progress.progress, 0)
    }

    func testLevelBoundaryIsInclusive() {
        // 恰好攒够第一级所需经验时应当已经进入 Lv2，而不是停在 Lv1 满条
        XCTAssertEqual(curve.level(forTotalEXP: 99), 1)
        XCTAssertEqual(curve.level(forTotalEXP: 100), 2)
    }

    func testRequirementGrowsMonotonically() {
        var previous = 0
        for level in 1..<curve.maxLevel {
            let requirement = curve.requirement(forLevel: level)
            XCTAssertGreaterThan(requirement, 0)
            XCTAssertGreaterThanOrEqual(requirement, previous)
            previous = requirement
        }
    }

    func testProgressIsConsistentWithCumulativeTable() {
        let totalForLevel10 = curve.totalEXPRequired(forLevel: 10)
        let progress = curve.progress(totalEXP: totalForLevel10 + 5)
        XCTAssertEqual(progress.level, 10)
        XCTAssertEqual(progress.currentEXP, 5)
        XCTAssertEqual(progress.requiredEXP, curve.requirement(forLevel: 10))
    }

    func testMaxLevelClamps() {
        let huge = curve.totalEXPRequired(forLevel: curve.maxLevel) * 10
        let progress = curve.progress(totalEXP: huge)
        XCTAssertEqual(progress.level, curve.maxLevel)
        XCTAssertTrue(progress.isMaxLevel)
        XCTAssertEqual(progress.progress, 1.0)
    }

    func testLevelsGainedListsEveryCrossedLevel() {
        let from = 0
        let to = curve.totalEXPRequired(forLevel: 4)
        XCTAssertEqual(curve.levelsGained(from: from, to: to), [2, 3, 4])
    }

    func testLevelsGainedIsEmptyWithinSameLevel() {
        XCTAssertTrue(curve.levelsGained(from: 10, to: 20).isEmpty)
    }

    /// 回滚经验时等级必须跟着回退，这是"等级不落库"这条设计的核心收益
    func testRollbackRestoresPreviousLevel() {
        let before = curve.level(forTotalEXP: 90)
        let after = curve.level(forTotalEXP: 90 + 50)
        XCTAssertEqual(before, 1)
        XCTAssertEqual(after, 2)
        XCTAssertEqual(curve.level(forTotalEXP: 140 - 50), before)
    }

    func testSkillCurveStartsCheaperButSteepens() {
        let playerCurve = LevelCurve(config: .init(base: 100, exponent: 1.5, maxLevel: 100))
        let skillCurve = LevelCurve(config: .init(base: 60, exponent: 1.6, maxLevel: 100))

        // 技能起步更便宜，玩家在新技能上能快速拿到正反馈
        XCTAssertLessThan(skillCurve.requirement(forLevel: 1), playerCurve.requirement(forLevel: 1))

        // 但技能曲线本身更陡：同样从 Lv1 到 Lv90，需求倍数增长得更快，
        // 所以把某个技能推到高等级仍然是长线目标
        let skillGrowth = Double(skillCurve.requirement(forLevel: 90)) / Double(skillCurve.requirement(forLevel: 1))
        let playerGrowth = Double(playerCurve.requirement(forLevel: 90)) / Double(playerCurve.requirement(forLevel: 1))
        XCTAssertGreaterThan(skillGrowth, playerGrowth)
    }
}
