import Foundation
import UserNotifications

/// 本地通知。全部是设备本地调度，不依赖任何服务端。
///
/// 调度策略是"全量重建"而不是增量修改：每次同步先清空自己安排的通知再重新登记。
/// 只会安排三类提醒：18 小时未打开、超过 1 天未使用、任务截止前 1 小时。
@MainActor
final class NotificationService {
    private let center = UNUserNotificationCenter.current()

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

    /// 按当前未打开时长与待办截止时间重建全部通知
    func sync(
        dueQuests: [NotificationPlanner.DueQuest],
        settings: AppSettings,
        now: Date = Date()
    ) async {
        await cancelAll()
        guard settings.notificationsEnabled, isAuthorized else { return }

        for item in NotificationPlanner.plan(now: now, dueQuests: dueQuests) {
            scheduleOnce(
                identifier: item.identifier,
                at: item.fireAt,
                title: item.title,
                body: item.body
            )
        }
    }

    // MARK: - 调度

    func scheduleOnce(identifier: String, at date: Date, title: String, body: String) {
        guard date.timeIntervalSinceNow >= 1 else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
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
            $0.hasPrefix(NotificationPlanner.Prefix.habit)
                || $0.hasPrefix(NotificationPlanner.Prefix.quest)
                || $0.hasPrefix(NotificationPlanner.Prefix.system)
        }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func pendingCount() async -> Int {
        await center.pendingNotificationRequests().count
    }
}
