import Foundation
import UserNotifications

/// 本地通知。全部是设备本地调度，不依赖任何服务端。
///
/// 调度策略是"全量重建"而不是增量修改：每次同步先清空自己安排的通知再重新登记。
/// 通知的数量级很小（几十条），全量重建换来的是绝对不会出现幽灵提醒。
@MainActor
final class NotificationService {
    private let center = UNUserNotificationCenter.current()

    private enum Prefix {
        static let habit = "habit-"
        static let quest = "quest-"
        static let system = "system-"
    }

    private(set) var isAuthorized = false

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            return granted
        } catch {
            isAuthorized = false
            return false
        }
    }

    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
    }

    // MARK: - 同步

    /// 根据当前的习惯、任务与设置重建全部通知
    func sync(habits: [Habit], quests: [Quest], settings: AppSettings) async {
        await cancelAll()
        guard settings.notificationsEnabled, isAuthorized else { return }

        for habit in habits where habit.hasReminder && !habit.isArchived {
            scheduleDaily(
                identifier: Prefix.habit + habit.id.uuidString,
                hour: habit.reminderHour,
                minute: habit.reminderMinute,
                title: L10n.t("reminder.title.habit"),
                body: habit.name
            )
        }

        for quest in quests {
            guard let dueAt = quest.dueAt, quest.status == .pending, dueAt > Date() else { continue }
            scheduleOnce(
                identifier: Prefix.quest + quest.id.uuidString,
                at: dueAt,
                title: L10n.t("reminder.title.quest"),
                body: quest.title
            )
        }

        if settings.planningReminderEnabled {
            scheduleDaily(
                identifier: Prefix.system + "planning",
                hour: settings.planningReminderHour,
                minute: settings.planningReminderMinute,
                title: ReminderKind.planning.defaultTitle,
                body: L10n.t("notify.planning.body")
            )
        }

        if settings.bedtimeReminderEnabled {
            scheduleDaily(
                identifier: Prefix.system + "bedtime",
                hour: settings.bedtimeReminderHour,
                minute: settings.bedtimeReminderMinute,
                title: ReminderKind.bedtime.defaultTitle,
                body: L10n.t("notify.bedtime.body")
            )
        }
    }

    // MARK: - 调度

    func scheduleDaily(identifier: String, hour: Int, minute: Int, title: String, body: String) {
        guard (0...23).contains(hour) else { return }
        var components = DateComponents()
        components.hour = hour
        components.minute = max(0, min(59, minute))

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(
            UNNotificationRequest(identifier: identifier, content: content, trigger: trigger),
            withCompletionHandler: nil
        )
    }

    func scheduleOnce(identifier: String, at date: Date, title: String, body: String) {
        guard date > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let interval = max(1, date.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        center.add(
            UNNotificationRequest(identifier: identifier, content: content, trigger: trigger),
            withCompletionHandler: nil
        )
    }

    func cancel(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    func cancelAll() async {
        let pending = await center.pendingNotificationRequests()
        let identifiers = pending.map(\.identifier).filter {
            $0.hasPrefix(Prefix.habit) || $0.hasPrefix(Prefix.quest) || $0.hasPrefix(Prefix.system)
        }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func pendingCount() async -> Int {
        await center.pendingNotificationRequests().count
    }
}
