import Foundation
import SwiftData

/// 一条有日期的可执行任务。主线 / 支线 / 重复实例共用这一个实体，
/// 类型由 `createdDay` 与 `scheduledDay` 的关系在创建时派生。
@Model
final class Quest {
    var id: UUID = UUID()
    var title: String = ""
    var detail: String = ""

    var kindRaw: String = QuestKind.side.rawValue
    var statusRaw: String = QuestStatus.pending.rawValue
    var difficultyRaw: Int = QuestDifficulty.normal.rawValue
    var priorityRaw: Int = QuestPriority.normal.rawValue

    var tags: [String] = []
    var estimatedMinutes: Int = 30

    var createdAt: Date = Date()
    var createdDayValue: Int = 0
    /// 计划执行的游戏日。晚于创建日即为"提前规划"，等于创建日即为"当天临时"。
    var scheduledDayValue: Int = 0
    var dueAt: Date?

    var completedAt: Date?
    var completedDayValue: Int = 0
    var isOverdue: Bool = false

    /// 由哪个重复模板生成，弱引用，避免关系图复杂化
    var templateID: UUID?
    var sortOrder: Int = 0

    /// 完成时该任务所属序列的连续次数，用于 `continuity` 加成
    var streakAtCompletion: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \QuestSkillLink.quest)
    var skillLinks: [QuestSkillLink]? = nil

    init(
        title: String,
        detail: String = "",
        kind: QuestKind = .side,
        difficulty: QuestDifficulty = .normal,
        priority: QuestPriority = .normal,
        tags: [String] = [],
        estimatedMinutes: Int = 30,
        createdDay: GameDay,
        scheduledDay: GameDay,
        dueAt: Date? = nil,
        templateID: UUID? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.detail = detail
        self.kindRaw = kind.rawValue
        self.difficultyRaw = difficulty.rawValue
        self.priorityRaw = priority.rawValue
        self.tags = tags
        self.estimatedMinutes = estimatedMinutes
        self.createdAt = Date()
        self.createdDayValue = createdDay.value
        self.scheduledDayValue = scheduledDay.value
        self.dueAt = dueAt
        self.templateID = templateID
    }

    // MARK: - 类型化访问

    var kind: QuestKind {
        get { QuestKind(rawValue: kindRaw) ?? .side }
        set { kindRaw = newValue.rawValue }
    }

    var status: QuestStatus {
        get { QuestStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var difficulty: QuestDifficulty {
        get { QuestDifficulty(rawValue: difficultyRaw) ?? .normal }
        set { difficultyRaw = newValue.rawValue }
    }

    var priority: QuestPriority {
        get { QuestPriority(rawValue: priorityRaw) ?? .normal }
        set { priorityRaw = newValue.rawValue }
    }

    var createdDay: GameDay {
        get { GameDay(value: createdDayValue) }
        set { createdDayValue = newValue.value }
    }

    var scheduledDay: GameDay {
        get { GameDay(value: scheduledDayValue) }
        set { scheduledDayValue = newValue.value }
    }

    var completedDay: GameDay? {
        get { completedDayValue == 0 ? nil : GameDay(value: completedDayValue) }
        set { completedDayValue = newValue?.value ?? 0 }
    }

    var isCompleted: Bool { status == .completed }

    static func boardOrder(_ lhs: Quest, _ rhs: Quest) -> Bool {
        QuestBoardOrdering.appearsBefore(
            lhsCompleted: lhs.isCompleted,
            lhsPriority: lhs.priorityRaw,
            lhsSortOrder: lhs.sortOrder,
            lhsCreatedAt: lhs.createdAt,
            rhsCompleted: rhs.isCompleted,
            rhsPriority: rhs.priorityRaw,
            rhsSortOrder: rhs.sortOrder,
            rhsCreatedAt: rhs.createdAt
        )
    }

    /// 是否提前规划。这个判断同时决定了任务类型与 `planning` 组的加成走向。
    var isPlannedAhead: Bool {
        kind == .repeating || scheduledDayValue > createdDayValue
    }

    /// 任务类型的派生规则，创建与改期时都走这里，保证只有一处定义
    static func derivedKind(createdDay: GameDay, scheduledDay: GameDay, fromTemplate: Bool) -> QuestKind {
        if fromTemplate { return .repeating }
        return scheduledDay > createdDay ? .main : .side
    }
}

/// 任务与技能的关联，携带经验权重。权重由用户在任务上自行配置，
/// 因此"完成开发任务 → Programming +40 / Game Design +20"完全由数据决定。
@Model
final class QuestSkillLink {
    var id: UUID = UUID()
    var skillID: UUID = UUID()
    /// 该技能能拿到任务最终经验的比例，1.0 表示全额
    var expShare: Double = 1.0

    var quest: Quest?

    init(skillID: UUID, expShare: Double = 1.0) {
        self.id = UUID()
        self.skillID = skillID
        self.expShare = expShare
    }
}
