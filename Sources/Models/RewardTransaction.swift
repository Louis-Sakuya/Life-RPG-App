import Foundation
import SwiftData

enum RewardSourceKind: String, Codable, CaseIterable, Sendable {
    case quest
    case habit
    case challenge
    case achievement
    case levelUp
    case streakBonus
    case purchase
    case manual
}

/// 奖励流水账。所有 EXP / Gold 的变动都必须先落一条流水。
///
/// 撤销完成时按流水记录的数值原样反向扣除，而不是重新跑一遍公式。
/// 原因是配置随时可能被调整，重算会让玩家的历史收益凭空变化。
@Model
final class RewardTransaction {
    var id: UUID = UUID()
    var sourceKindRaw: String = RewardSourceKind.quest.rawValue
    /// 来源实体的 id（任务 / 习惯 / 挑战），或规则 id 的哈希载体
    var sourceID: UUID?
    var sourceRuleID: String?
    var sourceTitle: String = ""

    var expDelta: Int = 0
    var goldDelta: Int = 0
    /// 技能经验分配明细，格式为 `skillID:exp`
    var skillEXPTokens: [String] = []

    var dayValue: Int = 0
    var createdAt: Date = Date()
    var isReverted: Bool = false
    var revertedAt: Date?

    /// 计算过程的可读快照，展示在流水详情里，也便于排查平衡问题
    var breakdown: String = ""

    init(
        sourceKind: RewardSourceKind,
        sourceID: UUID? = nil,
        sourceRuleID: String? = nil,
        sourceTitle: String = "",
        expDelta: Int,
        goldDelta: Int,
        skillEXP: [UUID: Int] = [:],
        day: GameDay,
        breakdown: String = ""
    ) {
        self.id = UUID()
        self.sourceKindRaw = sourceKind.rawValue
        self.sourceID = sourceID
        self.sourceRuleID = sourceRuleID
        self.sourceTitle = sourceTitle
        self.expDelta = expDelta
        self.goldDelta = goldDelta
        self.skillEXPTokens = skillEXP.map { "\($0.key.uuidString):\($0.value)" }
        self.dayValue = day.value
        self.createdAt = Date()
        self.breakdown = breakdown
    }

    var sourceKind: RewardSourceKind {
        get { RewardSourceKind(rawValue: sourceKindRaw) ?? .manual }
        set { sourceKindRaw = newValue.rawValue }
    }

    var day: GameDay {
        get { GameDay(value: dayValue) }
        set { dayValue = newValue.value }
    }

    var skillEXP: [UUID: Int] {
        var result: [UUID: Int] = [:]
        for token in skillEXPTokens {
            let parts = token.split(separator: ":")
            guard parts.count == 2, let uuid = UUID(uuidString: String(parts[0])), let value = Int(parts[1]) else {
                continue
            }
            result[uuid] = value
        }
        return result
    }
}
