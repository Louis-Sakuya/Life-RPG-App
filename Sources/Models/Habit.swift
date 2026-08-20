import Foundation
import SwiftData

/// 习惯。与重复任务的区别是交互成本：习惯是一键打卡、固定小额奖励，
/// 不参与任务的难度 / 时长 / 准时度加成体系，因此不共用奖励公式，只共用连续机制。
@Model
final class Habit {
    var id: UUID = UUID()
    var name: String = ""
    var iconName: String = "checkmark.circle.fill"
    var colorHex: String = "#2FA36B"

    /// 每天需要打卡的次数，支持"每天喝水 8 杯"这类目标
    var dailyTarget: Int = 1
    var reminderHour: Int = -1
    var reminderMinute: Int = 0

    var createdAt: Date = Date()
    var sortOrder: Int = 0
    var isArchived: Bool = false

    var streakCurrent: Int = 0
    var streakBest: Int = 0
    var streakLastDayValue: Int = 0
    var totalCheckIns: Int = 0

    /// 打卡时给哪些技能加经验
    var skillShareTokens: [String] = []

    @Relationship(deleteRule: .cascade, inverse: \HabitLog.habit)
    var logs: [HabitLog]? = nil

    init(
        name: String,
        iconName: String = "checkmark.circle.fill",
        colorHex: String = "#2FA36B",
        dailyTarget: Int = 1,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.dailyTarget = max(1, dailyTarget)
        self.createdAt = Date()
        self.sortOrder = sortOrder
    }

    var streak: StreakState {
        get {
            StreakState(
                current: streakCurrent,
                best: streakBest,
                lastDay: streakLastDayValue == 0 ? nil : GameDay(value: streakLastDayValue)
            )
        }
        set {
            streakCurrent = newValue.current
            streakBest = newValue.best
            streakLastDayValue = newValue.lastDay?.value ?? 0
        }
    }

    var hasReminder: Bool { reminderHour >= 0 }

    var skillShares: [SkillShare] {
        get { skillShareTokens.compactMap(SkillShare.init(token:)) }
        set { skillShareTokens = newValue.map(\.token) }
    }
}

/// 一天一条打卡记录，`count` 累加当天的打卡次数。
@Model
final class HabitLog {
    var id: UUID = UUID()
    var dayValue: Int = 0
    var count: Int = 0
    var updatedAt: Date = Date()

    var habit: Habit?

    init(day: GameDay, count: Int = 0) {
        self.id = UUID()
        self.dayValue = day.value
        self.count = count
        self.updatedAt = Date()
    }

    var day: GameDay {
        get { GameDay(value: dayValue) }
        set { dayValue = newValue.value }
    }
}
