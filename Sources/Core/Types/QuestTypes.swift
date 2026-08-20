import Foundation

/// 任务类型。刻意不为每种类型建独立实体：类型由创建日与计划日的关系派生，
/// 因此"昨天规划的任务今天自动成为主线"不需要任何迁移逻辑。
enum QuestKind: String, Codable, CaseIterable, Sendable {
    case main
    case side
    case repeating

    var title: String {
        switch self {
        case .main: return "主线"
        case .side: return "支线"
        case .repeating: return "重复"
        }
    }

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

    var title: String {
        switch self {
        case .trivial: return "轻松"
        case .easy: return "简单"
        case .normal: return "普通"
        case .hard: return "困难"
        case .epic: return "史诗"
        }
    }
}

enum QuestPriority: Int, Codable, CaseIterable, Identifiable, Sendable {
    case lowest = 1
    case low = 2
    case normal = 3
    case high = 4
    case critical = 5

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .lowest: return "最低"
        case .low: return "较低"
        case .normal: return "普通"
        case .high: return "较高"
        case .critical: return "最高"
        }
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
            return interval <= 1 ? "每天" : "每 \(interval) 天"
        case .weekly(let weekdays):
            let names = ["日", "一", "二", "三", "四", "五", "六"]
            let picked = weekdays.sorted().compactMap { index -> String? in
                guard index >= 1, index <= 7 else { return nil }
                return "周" + names[index - 1]
            }
            return picked.isEmpty ? "每周" : picked.joined(separator: " ")
        case .timesPerWeek(let count):
            return "每周 \(count) 次"
        case .monthly(let days):
            let picked = days.sorted().map { "\($0)日" }
            return picked.isEmpty ? "每月" : "每月 " + picked.joined(separator: " ")
        }
    }
}

/// 周期任务从本周开始算，还是从下周开始算
enum RecurrenceStartPolicy: String, Codable, CaseIterable, Sendable {
    case thisPeriod
    case nextPeriod

    var title: String {
        switch self {
        case .thisPeriod: return "从本周开始"
        case .nextPeriod: return "从下周开始"
        }
    }
}
