import XCTest
@testable import LifeRPG

@MainActor
final class FinishTemplateTests: XCTestCase {

    private func make() -> (container: AppContainer, player: Player) {
        let container = AppContainer(inMemory: true)
        container.bootstrap()
        let player = PlayerRepository(context: container.context).currentPlayer()
        return (container, player)
    }

    func testFinishPaysDurationRewardCancelsPendingAndStopsGeneration() {
        let (container, player) = make()
        let calendar = container.calendar
        let today = calendar.today
        let start = calendar.adding(days: -29, to: today)
        let template = QuestTemplate(
            title: "每日铸剑",
            recurrence: .daily(interval: 1),
            startDay: start
        )
        let repo = QuestRepository(context: container.context)
        repo.insert(template)
        let pending = Quest(
            title: template.title,
            kind: .repeating,
            createdDay: today,
            scheduledDay: today,
            templateID: template.id
        )
        repo.insert(pending)
        XCTAssertEqual(pending.status, .pending)

        let goldBefore = player.gold
        let expBefore = player.totalEXP
        let reward = container.quests.finishTemplate(template, player: player)

        XCTAssertNotNil(reward)
        XCTAssertTrue(template.isFinished)
        XCTAssertEqual(template.finishedDay, today)
        XCTAssertEqual(template.endDay, today)
        XCTAssertFalse(template.isActive)
        XCTAssertEqual(pending.status, .cancelled)
        XCTAssertEqual(player.totalRecurringSeriesFinished, 1)
        XCTAssertEqual(player.longestRecurringSeriesDays, 30)
        XCTAssertEqual(reward?.tier, .veteran)
        XCTAssertGreaterThan(player.gold, goldBefore)
        XCTAssertGreaterThan(player.totalEXP, expBefore)
        XCTAssertEqual(reward?.exp, player.totalEXP - expBefore)

        let generated = repo.ensurePendingRepeating(
            template: template,
            on: today,
            calendar: calendar,
            pausedDayValues: []
        )
        XCTAssertNil(generated)
    }

    func testFinishIsIdempotent() {
        let (container, player) = make()
        let template = QuestTemplate(
            title: "只封一次",
            startDay: container.calendar.today
        )
        QuestRepository(context: container.context).insert(template)

        XCTAssertNotNil(container.quests.finishTemplate(template, player: player))
        let finishedCount = player.totalRecurringSeriesFinished
        let gold = player.gold
        XCTAssertNil(container.quests.finishTemplate(template, player: player))
        XCTAssertEqual(player.totalRecurringSeriesFinished, finishedCount)
        XCTAssertEqual(player.gold, gold)
    }

    func testLongestSeriesKeepsTheBestRun() {
        let (container, player) = make()
        player.longestRecurringSeriesDays = 80
        let template = QuestTemplate(
            title: "短约",
            startDay: container.calendar.today
        )
        QuestRepository(context: container.context).insert(template)

        _ = container.quests.finishTemplate(template, player: player)
        XCTAssertEqual(player.longestRecurringSeriesDays, 80)
    }
}
