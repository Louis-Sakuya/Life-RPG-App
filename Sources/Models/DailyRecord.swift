import Foundation
import SwiftData

/// 每日聚合。统计页与热力图只读这张表，复杂度是 O(天数) 而不是 O(任务数)，
/// 因此即使积累几年数据，年度统计也不会变慢。
@Model
final class DailyRecord {
    var id: UUID = UUID()
    var dayValue: Int = 0

    var expEarned: Int = 0
    var goldEarned: Int = 0
    var questsCompleted: Int = 0
    var questsPlanned: Int = 0
    var mainQuestsCompleted: Int = 0
    var sideQuestsCompleted: Int = 0
    var habitCheckIns: Int = 0
    var habitTargets: Int = 0
    var focusMinutes: Int = 0
    var studyMinutes: Int = 0

    /// 每日结算的幂等闸门。一旦封存，补算逻辑不会再次处理这一天。
    var isFinalized: Bool = false
    var updatedAt: Date = Date()

    init(day: GameDay) {
        self.id = UUID()
        self.dayValue = day.value
        self.updatedAt = Date()
    }

    var day: GameDay {
        get { GameDay(value: dayValue) }
        set { dayValue = newValue.value }
    }

    /// 完成率同时考虑任务与习惯，避免只有习惯的日子完成率恒为 0
    var completionRate: Double {
        let total = questsPlanned + habitTargets
        guard total > 0 else { return 0 }
        let done = questsCompleted + min(habitCheckIns, habitTargets)
        return min(1.0, Double(done) / Double(total))
    }

    var isPerfect: Bool {
        (questsPlanned + habitTargets) > 0 && completionRate >= 1.0
    }

    /// 热力图的强度分级，0 表示没有任何活动
    var heatLevel: Int {
        let activity = questsCompleted * 2 + habitCheckIns
        switch activity {
        case 0: return 0
        case 1...2: return 1
        case 3...5: return 2
        case 6...9: return 3
        default: return 4
        }
    }
}
