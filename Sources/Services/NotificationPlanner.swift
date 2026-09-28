import Foundation

/// 本地通知只覆盖三种情况：18 小时未打开、超过 1 天未使用、任务截止前 1 小时。
/// 法术护盾在漏登时静默保护连胜，下次打开应用再弹出提示，不在日界（默认 4 点）推本地通知。
enum NotificationPlanner {
    static let eighteenHours: TimeInterval = 18 * 60 * 60
    static let oneDay: TimeInterval = 24 * 60 * 60
    static let dueLeadTime: TimeInterval = 60 * 60
    /// iOS 最多挂起 64 条。预留 2 条未打开提醒。
    static let maxQuestReminders = 62

    enum Prefix {
        static let habit = "habit-"
        static let quest = "quest-"
        static let system = "system-"
        static let inactivity18h = "system-inactivity-18h"
        static let inactivity1d = "system-inactivity-1d"
    }

    struct DueQuest: Equatable, Sendable {
        var id: UUID
        var title: String
        var dueAt: Date
    }

    struct Item: Equatable, Sendable {
        var identifier: String
        var fireAt: Date
        var title: String
        var body: String
    }

    static func questIdentifier(_ id: UUID) -> String {
        Prefix.quest + id.uuidString
    }

    static func plan(now: Date, dueQuests: [DueQuest]) -> [Item] {
        var items: [Item] = [
            Item(
                identifier: Prefix.inactivity18h,
                fireAt: now.addingTimeInterval(eighteenHours),
                title: L10n.t("notify.guild.title"),
                body: L10n.t("notify.inactivity_18h.body")
            ),
            Item(
                identifier: Prefix.inactivity1d,
                fireAt: now.addingTimeInterval(oneDay),
                title: L10n.t("notify.guild.title"),
                body: L10n.t("notify.inactivity_1d.body")
            )
        ]

        let questItems = dueQuests.compactMap { quest -> Item? in
            let fireAt = quest.dueAt.addingTimeInterval(-dueLeadTime)
            guard fireAt.timeIntervalSince(now) >= 1 else { return nil }
            return Item(
                identifier: questIdentifier(quest.id),
                fireAt: fireAt,
                title: quest.title,
                body: L10n.t("notify.quest_due.body")
            )
        }
        .sorted { $0.fireAt < $1.fireAt }

        items.append(contentsOf: questItems.prefix(maxQuestReminders))
        return items
    }
}
