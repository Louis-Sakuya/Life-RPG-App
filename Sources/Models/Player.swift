import Foundation
import SwiftData

/// 角色。`totalEXP` 是经验的唯一真相，等级由 `LevelCurve` 推导而不落库，
/// 这样回滚经验时等级会自动跟着回退，不会出现"扣了经验等级还留着"的漂移。
@Model
final class Player {
    var id: UUID = UUID()
    var nickname: String = "冒险者"
    /// SF Symbol 名称，作为默认头像
    var avatarSymbol: String = "person.crop.circle.fill"
    /// 用户自定义头像的图片数据
    @Attribute(.externalStorage) var avatarImageData: Data?

    var totalEXP: Int = 0
    var gold: Int = 0

    /// 已经发放过升级奖励的最高等级。撤销任务会让等级回落，
    /// 如果不记住这个水位，玩家可以靠"完成 → 撤销 → 再完成"反复领取同一级的奖励。
    var highestLevelRewarded: Int = 1

    var currentTitleID: String?
    var currentThemeID: String = "theme_default"
    var currentFrameID: String?

    var createdAt: Date = Date()
    /// 最后一次完成每日结算的游戏日，`DayCycleService` 以此判断需要补算多少天
    var lastActiveDayValue: Int = 0

    // MARK: - 连续登录

    var loginStreakCurrent: Int = 0
    var loginStreakBest: Int = 0
    var lastLoginDayValue: Int = 0
    var totalDaysPlayed: Int = 0

    // MARK: - 累计计数器
    //
    // 这些是缓存值。真相仍然分散在 Quest / HabitLog / DailyRecord 里，
    // 缓存的目的是让 MetricsSnapshot 的构建保持 O(1)，避免每次解锁检查都全表聚合。

    var totalQuestsCompleted: Int = 0
    var totalMainQuestsCompleted: Int = 0
    var totalSideQuestsCompleted: Int = 0
    var totalHabitCheckIns: Int = 0
    var totalEXPEarned: Int = 0
    var totalGoldEarned: Int = 0
    var totalStudyMinutes: Int = 0
    var totalFocusMinutes: Int = 0
    var perfectDays: Int = 0

    /// 历史上最早 / 最晚的完成时刻（逻辑小时，可能是 24...27 表示跨过午夜）
    var earliestCompletionHour: Int = 99
    var latestCompletionHour: Int = -1

    init(nickname: String = "冒险者") {
        self.id = UUID()
        self.nickname = nickname
        self.createdAt = Date()
    }

    var lastActiveDay: GameDay {
        get { GameDay(value: lastActiveDayValue) }
        set { lastActiveDayValue = newValue.value }
    }

    var lastLoginDay: GameDay {
        get { GameDay(value: lastLoginDayValue) }
        set { lastLoginDayValue = newValue.value }
    }

    var loginStreak: StreakState {
        get {
            StreakState(
                current: loginStreakCurrent,
                best: loginStreakBest,
                lastDay: lastLoginDayValue == 0 ? nil : GameDay(value: lastLoginDayValue)
            )
        }
        set {
            loginStreakCurrent = newValue.current
            loginStreakBest = newValue.best
            lastLoginDayValue = newValue.lastDay?.value ?? 0
        }
    }
}
