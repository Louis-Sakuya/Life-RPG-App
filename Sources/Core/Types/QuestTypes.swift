import Foundation

/// 任务类型。刻意不为每种类型建独立实体：类型由创建日与计划日的关系派生，
/// 因此"昨天规划的任务今天自动成为主线"不需要任何迁移逻辑。
enum QuestKind: String, Codable, CaseIterable, Sendable {
    case main
    case side
    case repeating

    var title: String { L10n.t("quest.kind.\(rawValue)") }

    var iconName: String {
        switch self {
        case .main: return "flag.fill"
        case .side: return "bolt.fill"
        case .repeating: return "repeat"
        }
    }
}

enum QuestStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case completed
    case cancelled
}

enum QuestDifficulty: Int, Codable, CaseIterable, Identifiable, Sendable {
    case trivial = 1
    case easy = 2
    case normal = 3
    case hard = 4
    case epic = 5

    var id: Int { rawValue }

    var title: String { L10n.t("quest.difficulty.\(String(describing: self))") }
}

enum QuestPriority: Int, Codable, CaseIterable, Identifiable, Sendable {
    case lowest = 1
    case low = 2
    case normal = 3
    case high = 4
    case critical = 5

    var id: Int { rawValue }

    var title: String { L10n.t("quest.priority.\(String(describing: self))") }
}

/// 工会任务栏排序：未完成在上、已完成沉底；同组内优先级从高到低。
enum QuestBoardOrdering {
    static func appearsBefore(
        lhsCompleted: Bool,
        lhsPriority: Int,
        lhsSortOrder: Int,
        lhsCreatedAt: Date,
        rhsCompleted: Bool,
        rhsPriority: Int,
        rhsSortOrder: Int,
        rhsCreatedAt: Date
    ) -> Bool {
        if lhsCompleted != rhsCompleted {
            return !lhsCompleted && rhsCompleted
        }
        if lhsPriority != rhsPriority {
            return lhsPriority > rhsPriority
        }
        if lhsSortOrder != rhsSortOrder {
            return lhsSortOrder < rhsSortOrder
        }
        return lhsCreatedAt < rhsCreatedAt
    }
}

/// 重复规律。新增规律时只需要扩展这个枚举与 `ScheduleEngine`，
/// 其余系统因为只消费生成出来的 `Quest` 实例而不受影响。
enum RecurrenceRule: Codable, Hashable, Sendable {
    /// 每 n 天
    case daily(interval: Int)
    /// 每周指定的星期（1 = 周日 ... 7 = 周六）
    case weekly(weekdays: [Int])
    /// 每周任意 n 天，不指定具体星期
    case timesPerWeek(count: Int)
    /// 每月的第几天
    case monthly(days: [Int])

    var displayText: String {
        switch self {
        case .daily(let interval):
            return interval <= 1 ? L10n.t("recurrence.daily") : L10n.format("recurrence.every_n_days", interval)
        case .weekly(let weekdays):
            let picked = weekdays.sorted().compactMap { index -> String? in
                guard index >= 1, index <= 7 else { return nil }
                return L10n.t("weekday.name.\(index)")
            }
            return picked.isEmpty ? L10n.t("recurrence.weekly_empty") : picked.joined(separator: " ")
        case .timesPerWeek(let count):
            return L10n.format("recurrence.times", count)
        case .monthly(let days):
            let picked = days.sorted().map { L10n.format("recurrence.month_day", $0) }
            return picked.isEmpty ? L10n.t("recurrence.monthly_empty") : L10n.format("recurrence.monthly_prefix", picked.joined(separator: " "))
        }
    }
}

/// 周期任务从本周开始算，还是从下周开始算
enum RecurrenceStartPolicy: String, Codable, CaseIterable, Sendable {
    case thisPeriod
    case nextPeriod

    var title: String {
        switch self {
        case .thisPeriod: return L10n.t("recurrence.this_period")
        case .nextPeriod: return L10n.t("recurrence.next_period")
        }
    }
}
