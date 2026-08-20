import Foundation
import SwiftData

enum AppearanceMode: String, Codable, CaseIterable, Sendable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }
}

/// 全局设置。以单例行存在，由 `SeedService` 保证有且仅有一条。
@Model
final class AppSettings {
    var id: UUID = UUID()

    /// 一天的起始时刻。改这个值会直接改变 `GameCalendar` 对"今天"的判断，
    /// 因此设置页上必须提示用户它会影响连续天数的统计口径。
    var dayStartHour: Int = 4

    var appearanceRaw: String = AppearanceMode.system.rawValue
    var useRPGTheme: Bool = true
    var notificationsEnabled: Bool = true
    var showWeather: Bool = false

    var planningReminderHour: Int = 21
    var planningReminderMinute: Int = 0
    var planningReminderEnabled: Bool = true

    var bedtimeReminderHour: Int = 23
    var bedtimeReminderMinute: Int = 30
    var bedtimeReminderEnabled: Bool = false

    /// 未完成的任务在跨天时是否自动顺延到第二天
    var carryOverUnfinished: Bool = false

    var lastBackupAt: Date?

    init() {
        self.id = UUID()
    }

    var appearance: AppearanceMode {
        get { AppearanceMode(rawValue: appearanceRaw) ?? .system }
        set { appearanceRaw = newValue.rawValue }
    }
}
