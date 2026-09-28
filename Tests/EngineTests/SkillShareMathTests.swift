import XCTest
@testable import LifeRPG

final class SkillShareMathTests: XCTestCase {

    func testEqualSharesSplitAcrossThreeSkills() {
        let ids = [UUID(), UUID(), UUID()]
        let shares = SkillShareMath.equalShares(ids: ids)
        XCTAssertEqual(shares.count, 3)
        XCTAssertEqual(SkillShareMath.total(shares), 1, accuracy: 0.001)
        XCTAssertTrue(SkillShareMath.isFullAllocation(shares))
    }

    func testSingleSkillTakesAll() {
        let id = UUID()
        let shares = SkillShareMath.equalShares(ids: [id])
        XCTAssertEqual(shares[id], 1)
    }

    func testRedistributeKeepsFullAllocation() {
        let a = UUID()
        let b = UUID()
        let c = UUID()
        var shares = SkillShareMath.equalShares(ids: [a, b, c])
        shares = SkillShareMath.setShare(0.5, for: a, in: shares, ids: [a, b, c], keepFullAllocation: true)
        XCTAssertEqual(shares[a], 0.5)
        XCTAssertEqual(SkillShareMath.total(shares), 1, accuracy: 0.001)
    }

    func testIndependentSlidersDoNotExceedOne() {
        let a = UUID()
        let b = UUID()
        var shares: [UUID: Double] = [a: 0.8, b: 0.1]
        shares = SkillShareMath.setShare(0.5, for: b, in: shares, ids: [a, b], keepFullAllocation: false)
        XCTAssertEqual(shares[b], 0.2)
        XCTAssertLessThanOrEqual(SkillShareMath.total(shares), 1.001)
    }

    func testSnapUsesFivePercentSteps() {
        XCTAssertEqual(SkillShareMath.snap(0.33), 0.35)
        XCTAssertEqual(SkillShareMath.snap(1.4), 1)
        XCTAssertEqual(SkillShareMath.snap(-0.2), 0)
    }

    func testSingleSkillTakesFullShare() {
        let id = UUID()
        XCTAssertEqual(SkillShareMath.single(id), [id: 1])
        XCTAssertTrue(SkillShareMath.single(nil).isEmpty)
        XCTAssertEqual(SkillShareMath.single(id).asSkillShares.first?.expShare, 1)
    }

    func testSelectedSkillsSplitEvenly() {
        let a = UUID()
        let b = UUID()
        let shares = SkillShareMath.selected([a, b])
        XCTAssertEqual(shares[a], 0.5)
        XCTAssertEqual(shares[b], 0.5)
        XCTAssertTrue(SkillShareMath.isFullAllocation(shares))
    }

    func testSelectedNoneYieldsEmptyShares() {
        XCTAssertTrue(SkillShareMath.selected([]).isEmpty)
    }
}
