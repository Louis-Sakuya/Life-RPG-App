import Foundation
import SwiftData

/// 重复任务的定义。它本身不是任务，只负责按周期生成 `Quest` 实例。
/// 这样"重复任务"在下游系统（奖励、统计、成就）眼里就是普通任务，不需要特殊分支。
@Model
final class QuestTemplate {
    var id: UUID = UUID()
    var title: String = ""
    var detail: String = ""

    var difficultyRaw: Int = QuestDifficulty.normal.rawValue
    var priorityRaw: Int = QuestPriority.normal.rawValue
    var tags: [String] = []
    var estimatedMinutes: Int = 30

    /// `RecurrenceRule` 的 JSON 编码。用 Data 存储而不是直接存 Codable 枚举，
    /// 是为了让带关联值的枚举在 SwiftData 迁移时行为可预期。
    var recurrenceData: Data = Data()
    var startPolicyRaw: String = RecurrenceStartPolicy.thisPeriod.rawValue
    /// 同一天最多完成几次。默认 1。
    var maxCompletionsPerDay: Int = 1
    /// 当前窗口（进行中或延期补债）的第一天
    var periodStartDayValue: Int = 0
    /// 本轮配额起算日。进入延期后保持不变，这样上一窗口已完成的次数仍计入欠债。
    var cycleOriginDayValue: Int = 0
    var periodStateRaw: String = RecurringPeriodState.active.rawValue

    var isActive: Bool = true
    /// 玩家主动完结的游戏日。0 表示仍在进行。
    var finishedDayValue: Int = 0
    /// 已走完的周期窗口数。每一窗算一段旅途。
    var completedJourneys: Int = 0
    var createdAt: Date = Date()
    var startDayValue: Int = 0
    var endDayValue: Int = 0

    /// 最后一次生成实例的游戏日，保证每日结算补算时不会重复生成
    var lastGeneratedDayValue: Int = 0

    /// 该模板下任务的连续完成状态
    var streakCurrent: Int = 0
    var streakBest: Int = 0
    var streakLastDayValue: Int = 0

    /// 生成的任务默认关联的技能，格式为 `skillID:share`
    var skillShareTokens: [String] = []

    init(
        title: String,
        detail: String = "",
        difficulty: QuestDifficulty = .normal,
        priority: QuestPriority = .normal,
        tags: [String] = [],
        estimatedMinutes: Int = 30,
        recurrence: RecurrenceRule = .daily(interval: 1),
        startPolicy: RecurrenceStartPolicy = .thisPeriod,
        startDay: GameDay
    ) {
        self.id = UUID()
        self.title = title
        self.detail = detail
        self.difficultyRaw = difficulty.rawValue
        self.priorityRaw = priority.rawValue
        self.tags = tags
        self.estimatedMinutes = estimatedMinutes
        self.recurrenceData = (try? JSONEncoder().encode(recurrence)) ?? Data()
        self.startPolicyRaw = startPolicy.rawValue
        self.createdAt = Date()
        self.startDayValue = startDay.value
        self.periodStartDayValue = startDay.value
        self.cycleOriginDayValue = startDay.value
    }

    var recurrence: RecurrenceRule {
        get {
            (try? JSONDecoder().decode(RecurrenceRule.self, from: recurrenceData)) ?? .daily(interval: 1)
        }
        set {
            recurrenceData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    var startPolicy: RecurrenceStartPolicy {
        get { RecurrenceStartPolicy(rawValue: startPolicyRaw) ?? .thisPeriod }
        set { startPolicyRaw = newValue.rawValue }
    }

    var difficulty: QuestDifficulty {
        get { QuestDifficulty(rawValue: difficultyRaw) ?? .normal }
        set { difficultyRaw = newValue.rawValue }
    }

    var priority: QuestPriority {
        get { QuestPriority(rawValue: priorityRaw) ?? .normal }
        set { priorityRaw = newValue.rawValue }
    }

    var startDay: GameDay {
        get { GameDay(value: startDayValue) }
        set { startDayValue = newValue.value }
    }

    var periodStart: GameDay {
        get { GameDay(value: periodStartDayValue == 0 ? startDayValue : periodStartDayValue) }
        set { periodStartDayValue = newValue.value }
    }

    var cycleOrigin: GameDay {
        get { GameDay(value: cycleOriginDayValue == 0 ? periodStart.value : cycleOriginDayValue) }
        set { cycleOriginDayValue = newValue.value }
    }

    var periodState: RecurringPeriodState {
        get { RecurringPeriodState(rawValue: periodStateRaw) ?? .active }
        set { periodStateRaw = newValue.rawValue }
    }

    var endDay: GameDay? {
        get { endDayValue == 0 ? nil : GameDay(value: endDayValue) }
        set { endDayValue = newValue?.value ?? 0 }
    }

    var finishedDay: GameDay? {
        get { finishedDayValue == 0 ? nil : GameDay(value: finishedDayValue) }
        set { finishedDayValue = newValue?.value ?? 0 }
    }

    var isFinished: Bool { finishedDayValue != 0 }

    var lastGeneratedDay: GameDay? {
        get { lastGeneratedDayValue == 0 ? nil : GameDay(value: lastGeneratedDayValue) }
        set { lastGeneratedDayValue = newValue?.value ?? 0 }
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

    var skillShares: [SkillShare] {
        get { skillShareTokens.compactMap(SkillShare.init(token:)) }
        set { skillShareTokens = newValue.map(\.token) }
    }
}

/// 技能经验分配。以 `uuid:share` 的字符串形式持久化，避免为一个两字段的结构再建实体。
struct SkillShare: Hashable, Sendable {
    var skillID: UUID
    var expShare: Double

    init(skillID: UUID, expShare: Double) {
        self.skillID = skillID
        self.expShare = expShare
    }

    init?(token: String) {
        let parts = token.split(separator: ":")
        guard parts.count == 2,
              let uuid = UUID(uuidString: String(parts[0])),
              let share = Double(parts[1]) else { return nil }
        self.skillID = uuid
        self.expShare = share
    }

    var token: String { "\(skillID.uuidString):\(expShare)" }
}
