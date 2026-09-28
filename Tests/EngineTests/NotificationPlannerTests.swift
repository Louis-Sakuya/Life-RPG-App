import XCTest
@testable import LifeRPG

final class NotificationPlannerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        L10n.bootstrap(bundle: Bundle(for: NotificationPlannerTests.self))
        L10n.language = .chinese
    }

    func testAlwaysSchedulesEighteenHourAndOneDayInactivityReminders() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let items = NotificationPlanner.plan(now: now, dueQuests: [])

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].identifier, NotificationPlanner.Prefix.inactivity18h)
        XCTAssertEqual(items[0].fireAt, now.addingTimeInterval(18 * 60 * 60))
        XCTAssertEqual(items[0].body, "今天还没有来工会看看呢～任务都顺利完成了吗")
        XCTAssertEqual(items[1].identifier, NotificationPlanner.Prefix.inactivity1d)
        XCTAssertEqual(items[1].fireAt, now.addingTimeInterval(24 * 60 * 60))
        XCTAssertEqual(items[1].body, "好久都没有来工会了呢～发布一些任务给明天的自己吧！")
    }

    func testQuestReminderFiresOneHourBeforeDue() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let questID = UUID()
        let dueAt = now.addingTimeInterval(3 * 60 * 60)
        let items = NotificationPlanner.plan(
            now: now,
            dueQuests: [.init(id: questID, title: "写周报", dueAt: dueAt)]
        )

        XCTAssertEqual(items.count, 3)
        let questItem = items[2]
        XCTAssertEqual(questItem.identifier, NotificationPlanner.questIdentifier(questID))
        XCTAssertEqual(questItem.fireAt, now.addingTimeInterval(2 * 60 * 60))
        XCTAssertEqual(questItem.title, "写周报")
        XCTAssertEqual(questItem.body, "这个任务要截止啦，快来完成领取报酬奖励吧！")
    }

    func testQuestDueWithinOneHourIsNotScheduled() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let items = NotificationPlanner.plan(
            now: now,
            dueQuests: [
                .init(id: UUID(), title: "马上截止", dueAt: now.addingTimeInterval(30 * 60)),
                .init(id: UUID(), title: "刚好一小时", dueAt: now.addingTimeInterval(60 * 60))
            ]
        )

        XCTAssertEqual(items.map(\.identifier), [
            NotificationPlanner.Prefix.inactivity18h,
            NotificationPlanner.Prefix.inactivity1d
        ])
    }

    func testQuestRemindersAreOrderedByFireTimeAndCapped() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let dueQuests = (0..<70).map { index in
            NotificationPlanner.DueQuest(
                id: UUID(),
                title: "任务\(index)",
                dueAt: now.addingTimeInterval(TimeInterval((70 - index) * 3600 + 3600))
            )
        }

        let items = NotificationPlanner.plan(now: now, dueQuests: dueQuests)
        let questItems = items.filter { $0.identifier.hasPrefix(NotificationPlanner.Prefix.quest) }
        XCTAssertEqual(questItems.count, NotificationPlanner.maxQuestReminders)
        XCTAssertEqual(questItems, questItems.sorted { $0.fireAt < $1.fireAt })
    }

    func testDoesNotScheduleStreakShieldAtDayBoundary() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let items = NotificationPlanner.plan(now: now, dueQuests: [])
        XCTAssertFalse(items.contains { $0.identifier.contains("streak-shield") })
        XCTAssertFalse(items.contains { $0.title.contains("法术护盾") })
    }

    func testEnglishCopyFollowsLanguage() {
        L10n.language = .english
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let items = NotificationPlanner.plan(
            now: now,
            dueQuests: [.init(id: UUID(), title: "Report", dueAt: now.addingTimeInterval(3 * 60 * 60))]
        )

        XCTAssertEqual(items[0].title, "A note from the guild")
        XCTAssertEqual(items[0].body, "You haven't stopped by the guild today~ Did the quests go well?")
        XCTAssertEqual(items[1].body, "It's been a while since you visited the guild~ Publish some quests for tomorrow's you!")
        XCTAssertEqual(items[2].body, "This quest is about to expire! Come finish it and claim your rewards!")
    }
}
