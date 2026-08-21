import XCTest
@testable import LifeRPG

final class QuestBoardOrderingTests: XCTestCase {

    private let earlier = Date(timeIntervalSince1970: 1_700_000_000)
    private let later = Date(timeIntervalSince1970: 1_700_000_100)

    func testCompletedQuestsSinkToBottom() {
        XCTAssertTrue(
            QuestBoardOrdering.appearsBefore(
                lhsCompleted: false, lhsPriority: 1, lhsSortOrder: 0, lhsCreatedAt: later,
                rhsCompleted: true, rhsPriority: 5, rhsSortOrder: 0, rhsCreatedAt: earlier
            )
        )
        XCTAssertFalse(
            QuestBoardOrdering.appearsBefore(
                lhsCompleted: true, lhsPriority: 5, lhsSortOrder: 0, lhsCreatedAt: earlier,
                rhsCompleted: false, rhsPriority: 1, rhsSortOrder: 0, rhsCreatedAt: later
            )
        )
    }

    func testOpenQuestsSortByPriorityDescending() {
        XCTAssertTrue(
            QuestBoardOrdering.appearsBefore(
                lhsCompleted: false, lhsPriority: 5, lhsSortOrder: 2, lhsCreatedAt: later,
                rhsCompleted: false, rhsPriority: 3, rhsSortOrder: 0, rhsCreatedAt: earlier
            )
        )
        XCTAssertFalse(
            QuestBoardOrdering.appearsBefore(
                lhsCompleted: false, lhsPriority: 3, lhsSortOrder: 0, lhsCreatedAt: earlier,
                rhsCompleted: false, rhsPriority: 5, rhsSortOrder: 2, rhsCreatedAt: later
            )
        )
    }

    func testEqualPriorityKeepsSortOrderThenCreatedAt() {
        XCTAssertTrue(
            QuestBoardOrdering.appearsBefore(
                lhsCompleted: false, lhsPriority: 3, lhsSortOrder: 0, lhsCreatedAt: later,
                rhsCompleted: false, rhsPriority: 3, rhsSortOrder: 1, rhsCreatedAt: earlier
            )
        )
        XCTAssertTrue(
            QuestBoardOrdering.appearsBefore(
                lhsCompleted: false, lhsPriority: 3, lhsSortOrder: 0, lhsCreatedAt: earlier,
                rhsCompleted: false, rhsPriority: 3, rhsSortOrder: 0, rhsCreatedAt: later
            )
        )
    }
}
