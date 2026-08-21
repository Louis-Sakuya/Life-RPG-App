import Foundation
import SwiftData

/// 角色。`totalEXP` 是经验的唯一真相，等级由 `LevelCurve` 推导而不落库，
/// 这样回滚经验时等级会自动跟着回退，不会出现"扣了经验等级还留着"的漂移。
@Model
final class Player {
    static let defaultNickname = "冒险者"

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

    var bodyEXP: Int = 0
    var mindEXP: Int = 0
    var lifeEXP: Int = 0
    var socialEXP: Int = 0
    var creationEXP: Int = 0
    var luckyEXP: Int = 0
    /// 上次进行幸运日判定的游戏日。同一天只判定一次。
    var fortuneRollDayValue: Int = 0
    /// 当天生效的命运档位 id，未触发则为空
    var activeFortuneID: String = ""

    /// 历史上最早 / 最晚的完成时刻（逻辑小时，可能是 24...27 表示跨过午夜）
    var earliestCompletionHour: Int = 99
    var latestCompletionHour: Int = -1

    /// 当前可掌握的技能栏位数。开局为配置表的初始值，升级选择栏位后增加。
    var skillSlotCap: Int = 5
    /// 已发放金币但还没选完额外奖励的升级次数。杀进程后靠这个把选择界面找回来。
    var unclaimedLevelUpChoices: Int = 0

    var bodyPoints: Int = 0
    var mindPoints: Int = 0
    var lifePoints: Int = 0
    var socialPoints: Int = 0
    var creationPoints: Int = 0

    init(nickname: String = Player.defaultNickname) {
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

    func exp(for stat: CoreStatID) -> Int {
        switch stat {
        case .body: return bodyEXP
        case .mind: return mindEXP
        case .life: return lifeEXP
        case .social: return socialEXP
        case .creation: return creationEXP
        }
    }

    func setEXP(_ value: Int, for stat: CoreStatID) {
        let clamped = max(0, value)
        switch stat {
        case .body: bodyEXP = clamped
        case .mind: mindEXP = clamped
        case .life: lifeEXP = clamped
        case .social: socialEXP = clamped
        case .creation: creationEXP = clamped
        }
    }

    func addEXP(_ delta: Int, to stat: CoreStatID) {
        setEXP(exp(for: stat) + delta, for: stat)
    }

    func allocatedPoints(for stat: CoreStatID) -> Int {
        switch stat {
        case .body: return bodyPoints
        case .mind: return mindPoints
        case .life: return lifePoints
        case .social: return socialPoints
        case .creation: return creationPoints
        }
    }

    func addAllocatedPoint(to stat: CoreStatID) {
        switch stat {
        case .body: bodyPoints += 1
        case .mind: mindPoints += 1
        case .life: lifePoints += 1
        case .social: socialPoints += 1
        case .creation: creationPoints += 1
        }
    }

    func setAllocatedPoints(_ value: Int, for stat: CoreStatID) {
        let clamped = max(0, value)
        switch stat {
        case .body: bodyPoints = clamped
        case .mind: mindPoints = clamped
        case .life: lifePoints = clamped
        case .social: socialPoints = clamped
        case .creation: creationPoints = clamped
        }
    }
}
