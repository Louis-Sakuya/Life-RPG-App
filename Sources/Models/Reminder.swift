import Foundation
import SwiftData

enum ReminderKind: String, Codable, CaseIterable, Sendable {
    case quest
    case habit
    case planning
    case bedtime
    case streak
    case challenge

    var displayName: String {
        switch self {
        case .quest: return "任务提醒"
        case .habit: return "习惯提醒"
        case .planning: return "明日规划提醒"
        case .bedtime: return "睡觉提醒"
        case .streak: return "连续签到提醒"
        case .challenge: return "挑战提醒"
        }
    }

    var defaultTitle: String {
        switch self {
        case .quest: return "任务到点了"
        case .habit: return "该打卡了"
        case .planning: return "规划明天的主线"
        case .bedtime: return "该休息了"
        case .streak: return "别断了连续记录"
        case .challenge: return "挑战进度检查"
        }
    }
}

/// 本地通知的调度记录。真正的注册在 `NotificationService`，
/// 这张表只是为了让用户能在设置里查看与撤销已安排的提醒。
@Model
final class Reminder {
    var id: UUID = UUID()
    var kindRaw: String = ReminderKind.habit.rawValue
    var title: String = ""
    var body: String = ""
    var hour: Int = 21
    var minute: Int = 0
    var isEnabled: Bool = true
    /// 关联的任务 / 习惯 id，全局提醒为 nil
    var targetID: UUID?
    /// 一次性提醒的触发时刻，重复提醒为 nil
    var fireDate: Date?
    var createdAt: Date = Date()

    init(
        kind: ReminderKind,
        title: String? = nil,
        body: String = "",
        hour: Int = 21,
        minute: Int = 0,
        targetID: UUID? = nil,
        fireDate: Date? = nil
    ) {
        self.id = UUID()
        self.kindRaw = kind.rawValue
        self.title = title ?? kind.defaultTitle
        self.body = body
        self.hour = hour
        self.minute = minute
        self.targetID = targetID
        self.fireDate = fireDate
        self.createdAt = Date()
    }

    var kind: ReminderKind {
        get { ReminderKind(rawValue: kindRaw) ?? .habit }
        set { kindRaw = newValue.rawValue }
    }

    /// 通知中心里使用的标识符，撤销时按这个前缀批量移除
    var notificationIdentifier: String { "reminder-\(id.uuidString)" }
}
