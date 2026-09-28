import XCTest
@testable import LifeRPG

@MainActor
final class CompletionFeedbackTests: XCTestCase {

    func testCompletingQuestPresentsInlineRewardAndSpark() throws {
        let store = GameStore(container: AppContainer(inMemory: true))
        store.bootstrap()
        store.createQuest(title: "Inline reward", scheduledDay: store.today)

        let quest = try XCTUnwrap(store.todayQuests.first)
        store.toggleQuest(quest)

        let popup = try XCTUnwrap(store.rewardPopup)
        XCTAssertEqual(popup.sourceID, quest.id)
        XCTAssertGreaterThan(popup.exp, 0)
        XCTAssertGreaterThan(popup.gold, 0)
        XCTAssertEqual(store.rowSparkSourceID, quest.id)
        XCTAssertNil(store.completeFXToken, "全屏火花应留给商店特效，默认只走行内")
    }
}
