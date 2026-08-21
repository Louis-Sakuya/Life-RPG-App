import Foundation
import SwiftData

enum AppearanceMode: String, Codable, CaseIterable, Sendable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: return L10n.t("appearance.system")
        case .light: return L10n.t("appearance.light")
        case .dark: return L10n.t("appearance.dark")
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

    /// `system` / `zh-Hans` / `en`。界面语言与系统语言解耦，可在设置里即时切换。
    var languageRaw: String = AppLanguage.system.rawValue

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

    /// 是否已经走完首次冒险者设定。老存档由 `SeedService` 在启动时补记。
    var hasCompletedOnboarding: Bool = false

    /// 测试用：商店不再检查等级，金币视为无限，购买不扣费。真实余额不会被改写。
    var testShopSandbox: Bool = false

    var lastBackupAt: Date?

    init() {
        self.id = UUID()
    }

    var appearance: AppearanceMode {
        get { AppearanceMode(rawValue: appearanceRaw) ?? .system }
        set { appearanceRaw = newValue.rawValue }
    }

    var language: AppLanguage {
        get { AppLanguage(rawValue: languageRaw) ?? .system }
        set { languageRaw = newValue.rawValue }
    }
}
