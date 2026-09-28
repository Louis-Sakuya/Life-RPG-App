import XCTest
@testable import LifeRPG

final class QuestDifficultyTests: XCTestCase {

    func testDurationMapsToDifficultyBands() {
        XCTAssertEqual(QuestDifficulty.fromEstimatedMinutes(5), .trivial)
        XCTAssertEqual(QuestDifficulty.fromEstimatedMinutes(15), .trivial)
        XCTAssertEqual(QuestDifficulty.fromEstimatedMinutes(16), .easy)
        XCTAssertEqual(QuestDifficulty.fromEstimatedMinutes(29), .easy)
        XCTAssertEqual(QuestDifficulty.fromEstimatedMinutes(30), .normal)
        XCTAssertEqual(QuestDifficulty.fromEstimatedMinutes(59), .normal)
        XCTAssertEqual(QuestDifficulty.fromEstimatedMinutes(60), .hard)
        XCTAssertEqual(QuestDifficulty.fromEstimatedMinutes(119), .hard)
        XCTAssertEqual(QuestDifficulty.fromEstimatedMinutes(120), .epic)
        XCTAssertEqual(QuestDifficulty.fromEstimatedMinutes(600), .epic)
    }
}