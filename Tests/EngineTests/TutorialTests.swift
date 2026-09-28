import XCTest
@testable import LifeRPG

@MainActor
final class TutorialTests: XCTestCase {

    private func makeStore() -> GameStore {
        let store = GameStore(container: AppContainer(inMemory: true))
        store.bootstrap()
        return store
    }

    func testCompleteOnboardingStartsForcedTutorial() {
        let store = makeStore()
        store.completeOnboarding(nickname: "旅人", skills: [])
        XCTAssertEqual(store.tutorialStep, .welcome)
        XCTAssertTrue(store.isTutorialActive)
        XCTAssertFalse(store.settings.hasCompletedTutorial)
    }

    func testLegacySaveSkipsTutorial() {
        let container = AppContainer(inMemory: true)
        let player = PlayerRepository(context: container.context).currentPlayer()
        player.nickname = "老冒险者"
        player.totalEXP = 80
        container.save()

        let store = GameStore(container: container)
        store.bootstrap()
        XCTAssertFalse(store.needsOnboarding)
        XCTAssertNil(store.tutorialStep)
        XCTAssertTrue(store.settings.hasCompletedTutorial)
        XCTAssertFalse(store.isTutorialActive)
    }

    func testPublishingMainAndSideAdvancesTutorial() {
        let store = makeStore()
        store.completeOnboarding(nickname: "旅人", skills: [])
        store.performTutorialPrimary()
        store.performTutorialHighlightAction()
        store.performTutorialHighlightAction()
        store.performTutorialHighlightAction()
        XCTAssertEqual(store.tutorialStep, .fillMain)

        store.createQuest(
            title: "跑步",
            scheduledDay: store.container.calendar.adding(days: 1, to: store.today),
            preferredKind: .main
        )
        XCTAssertEqual(store.tutorialStep, .tapPublishSide)

        store.performTutorialHighlightAction()
        store.performTutorialHighlightAction()
        XCTAssertEqual(store.tutorialStep, .fillSide)

        store.createQuest(
            title: "倒垃圾",
            scheduledDay: store.today,
            preferredKind: .side
        )
        XCTAssertEqual(store.tutorialStep, .goGrowth)
    }

    func testCreatingHabitFinishesTheForcedLoop() {
        let store = makeStore()
        store.completeOnboarding(nickname: "旅人", skills: [])
        store.performTutorialPrimary()
        store.performTutorialHighlightAction()
        store.performTutorialHighlightAction()
        store.performTutorialHighlightAction()
        store.createQuest(
            title: "跑步",
            scheduledDay: store.container.calendar.adding(days: 1, to: store.today),
            preferredKind: .main
        )
        store.performTutorialHighlightAction()
        store.performTutorialHighlightAction()
        store.createQuest(
            title: "倒垃圾",
            scheduledDay: store.today,
            preferredKind: .side
        )
        store.performTutorialHighlightAction()
        store.performTutorialHighlightAction()
        store.performTutorialHighlightAction()
        XCTAssertEqual(store.tutorialStep, .fillHabit)

        store.createHabit(
            name: "喝水",
            iconName: "drop.fill",
            colorHex: "#3EC1B3",
            dailyTarget: 1,
            reminderHour: -1,
            reminderMinute: 0,
            skillShares: []
        )
        XCTAssertEqual(store.tutorialStep, .done)

        store.performTutorialPrimary()
        XCTAssertNil(store.tutorialStep)
        XCTAssertTrue(store.settings.hasCompletedTutorial)
        XCTAssertFalse(store.isTutorialActive)
        XCTAssertEqual(TutorialStep.done.host, .tabs)
    }

    func testCreatingHabitOnGrowthStepFinishesTutorial() {
        let store = makeStore()
        store.completeOnboarding(nickname: "旅人", skills: [])
        store.performTutorialPrimary()
        store.performTutorialHighlightAction()
        store.performTutorialHighlightAction()
        store.performTutorialHighlightAction()
        store.createQuest(
            title: "跑步",
            scheduledDay: store.container.calendar.adding(days: 1, to: store.today),
            preferredKind: .main
        )
        store.performTutorialHighlightAction()
        store.performTutorialHighlightAction()
        store.createQuest(
            title: "倒垃圾",
            scheduledDay: store.today,
            preferredKind: .side
        )
        XCTAssertEqual(store.tutorialStep, .goGrowth)

        store.createHabit(
            name: "喝水",
            iconName: "drop.fill",
            colorHex: "#3EC1B3",
            dailyTarget: 1,
            reminderHour: -1,
            reminderMinute: 0,
            skillShares: []
        )
        XCTAssertEqual(store.tutorialStep, .done)
    }

    func testExistingHabitResumesAtDoneInsteadOfGrowth() {
        let store = makeStore()
        store.completeOnboarding(nickname: "旅人", skills: [])
        store.performTutorialPrimary()
        store.performTutorialHighlightAction()
        store.performTutorialHighlightAction()
        store.performTutorialHighlightAction()
        store.createQuest(
            title: "跑步",
            scheduledDay: store.container.calendar.adding(days: 1, to: store.today),
            preferredKind: .main
        )
        store.performTutorialHighlightAction()
        store.performTutorialHighlightAction()
        store.createQuest(
            title: "倒垃圾",
            scheduledDay: store.today,
            preferredKind: .side
        )
        store.createHabit(
            name: "喝水",
            iconName: "drop.fill",
            colorHex: "#3EC1B3",
            dailyTarget: 1,
            reminderHour: -1,
            reminderMinute: 0,
            skillShares: []
        )
        store.settings.tutorialStepRaw = TutorialStep.fillHabit.rawValue
        store.settings.hasCompletedTutorial = false
        store.container.save()

        let restored = GameStore(container: store.container)
        restored.bootstrap()
        XCTAssertEqual(restored.tutorialStep, .done)
    }

    func testResetAccountRestartsTutorialAfterOnboarding() {
        let store = makeStore()
        store.completeOnboarding(nickname: "旅人", skills: [])
        store.performTutorialPrimary()
        XCTAssertNoThrow(try store.resetAccount())
        XCTAssertTrue(store.needsOnboarding)
        XCTAssertNil(store.tutorialStep)

        store.completeOnboarding(nickname: "新旅人", skills: [])
        XCTAssertEqual(store.tutorialStep, .welcome)
    }
}
