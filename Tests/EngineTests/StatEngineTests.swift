import XCTest
@testable import LifeRPG

final class StatEngineTests: XCTestCase {

    func testSwimmingSplitsBodyAndLife() {
        let skillID = UUID()
        let skill = SkillSnapshot(
            id: skillID,
            affinities: [
                StatAffinity(stat: .body, weight: 0.7),
                StatAffinity(stat: .life, weight: 0.3)
            ]
        )
        let result = StatEngine.distribute(skillEXP: [skillID: 100], skills: [skillID: skill])
        XCTAssertEqual(result[.body], 70)
        XCTAssertEqual(result[.life], 30)
        XCTAssertNil(result[.mind])
    }

    func testEmptyAffinitiesProduceNoStatEXP() {
        let skillID = UUID()
        let skill = SkillSnapshot(id: skillID, affinities: [])
        let result = StatEngine.distribute(skillEXP: [skillID: 40], skills: [skillID: skill])
        XCTAssertTrue(result.isEmpty)
    }

    func testLuckyIsNeverFed() {
        let skillID = UUID()
        let skill = SkillSnapshot(
            id: skillID,
            affinities: [StatAffinity(stat: .creation, weight: 1)]
        )
        let result = StatEngine.distribute(skillEXP: [skillID: 20], skills: [skillID: skill])
        XCTAssertEqual(result[.creation], 20)
        XCTAssertEqual(result.count, 1)
    }

    func testMultipleSkillsAccumulate() {
        let a = UUID()
        let b = UUID()
        let skills: [UUID: SkillSnapshot] = [
            a: SkillSnapshot(id: a, affinities: [StatAffinity(stat: .mind, weight: 1)]),
            b: SkillSnapshot(id: b, affinities: [StatAffinity(stat: .mind, weight: 0.5), StatAffinity(stat: .creation, weight: 0.5)])
        ]
        let result = StatEngine.distribute(skillEXP: [a: 10, b: 10], skills: skills)
        XCTAssertEqual(result[.mind], 15)
        XCTAssertEqual(result[.creation], 5)
    }
}
