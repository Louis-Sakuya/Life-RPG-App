import XCTest
@testable import LifeRPG

@MainActor
final class DayCycleFailTests: XCTestCase {

    private func make() -> (container: AppContainer, player: Player, settings: AppSettings) {
        let container = AppContainer(inMemory: true)
        container.bootstrap()
        let repo = PlayerRepository(context: container.context)
        return (container, repo.currentPlayer(), repo.settings())
    }

    func testSingleQuestFailsAfterMoreThanThreeDays() {
        let (container, player, settings) = make()
        let calendar = container.calendar
        let today = calendar.today
        let quests = QuestRepository(context: container.context)
        quests.insert(
            Quest(
                title: "过期的信",
                kind: .side,
                createdDay: calendar.adding(days: -4, to: today),
                scheduledDay: calendar.adding(days: -4, to: today)
            )
        )

        let report = container.dayCycle.runIfNeeded(player: player, settings: settings)

        XCTAssertEqual(report.newlyFailed.map(\.title), ["过期的信"])
        XCTAssertEqual(quests.allFailedRecords().count, 1)
        XCTAssertTrue(quests.pendingQuests().isEmpty)
    }

    func testSingleQuestStaysOverdueOnTheThirdDay() {
        let (container, player, settings) = make()
        let calendar = container.calendar
        let today = calendar.today
        let quests = QuestRepository(context: container.context)
        let quest = quests.insert(
            Quest(
                title: "还能补",
                kind: .main,
                createdDay: calendar.adding(days: -3, to: today),
                scheduledDay: calendar.adding(days: -3, to: today)
            )
        )

        let report = container.dayCycle.runIfNeeded(player: player, settings: settings)

        XCTAssertTrue(report.newlyFailed.isEmpty)
        XCTAssertTrue(quest.isOverdue)
        XCTAssertEqual(quest.status, .pending)
        XCTAssertTrue(quests.allFailedRecords().isEmpty)
    }

    func testPausedDayKeepsSingleFromFailing() {
        let (container, player, settings) = make()
        let calendar = container.calendar
        let today = calendar.today
        player.pause(calendar.adding(days: -2, to: today))
        let quests = QuestRepository(context: container.context)
        quests.insert(
            Quest(
                title: "请假保住了",
                createdDay: calendar.adding(days: -4, to: today),
                scheduledDay: calendar.adding(days: -4, to: today)
            )
        )

        let report = container.dayCycle.runIfNeeded(player: player, settings: settings)

        XCTAssertTrue(report.newlyFailed.isEmpty)
        XCTAssertEqual(quests.pendingQuests().count, 1)
    }

    func testWeeklyQuotaEntersGraceAfterOneWindowThenFailsAfterTheNext() throws {
        let (container, player, settings) = make()
        let calendar = container.calendar
        let today = calendar.today
        let start = calendar.adding(days: -14, to: today)
        let template = QuestTemplate(
            title: "游泳",
            recurrence: .timesPerWeek(count: 2),
            startDay: start
        )
        template.periodStart = start
        template.cycleOrigin = start
        QuestRepository(context: container.context).insert(template)

        let report = container.dayCycle.runIfNeeded(player: player, settings: settings)

        XCTAssertEqual(report.newlyFailed.map(\.title), ["游泳"])
        XCTAssertEqual(template.periodState, .active)
        XCTAssertEqual(template.periodStart, today)
        let record = try XCTUnwrap(QuestRepository(context: container.context).allFailedRecords().first)
        XCTAssertEqual(record.progressDone, 0)
        XCTAssertEqual(record.progressTarget, 2)
    }

    func testMeetingQuotaRecordsAJourney() {
        let (container, player, settings) = make()
        let calendar = container.calendar
        let today = calendar.today
        let start = calendar.adding(days: -7, to: today)
        let template = QuestTemplate(
            title: "每日赶路",
            recurrence: .timesPerWeek(count: 2),
            startDay: start
        )
        template.periodStart = start
        template.cycleOrigin = start
        let repo = QuestRepository(context: container.context)
        repo.insert(template)
        for offset in [6, 5] {
            let day = calendar.adding(days: -offset, to: today)
            let quest = Quest(
                title: template.title,
                kind: .repeating,
                createdDay: day,
                scheduledDay: day,
                templateID: template.id
            )
            quest.status = .completed
            quest.completedDay = day
            repo.insert(quest)
        }

        let report = container.dayCycle.runIfNeeded(player: player, settings: settings)

        XCTAssertTrue(report.newlyFailed.isEmpty)
        XCTAssertEqual(template.completedJourneys, 1)
        XCTAssertEqual(template.periodState, .active)
    }

    func testWeeklyQuotaOnlyGoesOverdueAfterTheFirstWindow() {
        let (container, player, settings) = make()
        let calendar = container.calendar
        let today = calendar.today
        let start = calendar.adding(days: -7, to: today)
        let template = QuestTemplate(
            title: "游泳",
            recurrence: .timesPerWeek(count: 2),
            startDay: start
        )
        template.periodStart = start
        template.cycleOrigin = start
        QuestRepository(context: container.context).insert(template)

        let report = container.dayCycle.runIfNeeded(player: player, settings: settings)

        XCTAssertTrue(report.newlyFailed.isEmpty)
        XCTAssertEqual(template.periodState, .grace)
        XCTAssertEqual(template.periodStart, today)
    }

    func testStreakShieldProtectsAOneDayGap() {
        let (container, player, settings) = make()
        let calendar = container.calendar
        let today = calendar.today
        player.hasStreakShield = true
        player.loginStreakCurrent = 5
        player.loginStreakBest = 5
        player.lastLoginDay = calendar.adding(days: -2, to: today)

        let report = container.dayCycle.runIfNeeded(player: player, settings: settings)

        XCTAssertTrue(report.streakShieldTriggered)
        XCTAssertFalse(player.hasStreakShield)
        XCTAssertTrue(player.pendingStreakShieldAlert)
        XCTAssertEqual(player.loginStreakCurrent, 6)
    }
}
