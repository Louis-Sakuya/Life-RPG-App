import Foundation
import SwiftData

/// 长期挑战。它的进度不由用户勾选，而是由统计量推导，因此和成就共用同一套解锁引擎。
/// 内置挑战从 `unlock_rules.json` 播种进来，用户也可以自建，两者走完全相同的评估路径。
@Model
final class Challenge {
    var id: UUID = UUID()
    /// 内置挑战对应 `unlock_rules.json` 里的规则 id，自建挑战为 nil
    var ruleID: String?

    var title: String = ""
    var detail: String = ""
    var iconName: String = "trophy.fill"

    var metricKey: String = MetricKey.totalQuestsCompleted
    var metricParam: String?
    var comparatorRaw: String = MetricComparator.gte.rawValue
    var threshold: Double = 1

    var rewardEXP: Int = 0
    var rewardGold: Int = 0
    var rewardTitleID: String?

    var isCompleted: Bool = false
    var completedDayValue: Int = 0
    var createdAt: Date = Date()
    var isArchived: Bool = false

    init(
        title: String,
        detail: String = "",
        iconName: String = "trophy.fill",
        metricKey: String = MetricKey.totalQuestsCompleted,
        metricParam: String? = nil,
        comparator: MetricComparator = .gte,
        threshold: Double = 1,
        rewardEXP: Int = 0,
        rewardGold: Int = 0,
        rewardTitleID: String? = nil,
        ruleID: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.detail = detail
        self.iconName = iconName
        self.metricKey = metricKey
        self.metricParam = metricParam
        self.comparatorRaw = comparator.rawValue
        self.threshold = threshold
        self.rewardEXP = rewardEXP
        self.rewardGold = rewardGold
        self.rewardTitleID = rewardTitleID
        self.ruleID = ruleID
        self.createdAt = Date()
    }

    var comparator: MetricComparator {
        get { MetricComparator(rawValue: comparatorRaw) ?? .gte }
        set { comparatorRaw = newValue.rawValue }
    }

    var completedDay: GameDay? {
        get { completedDayValue == 0 ? nil : GameDay(value: completedDayValue) }
        set { completedDayValue = newValue?.value ?? 0 }
    }

    var condition: UnlockCondition {
        UnlockCondition(metric: metricKey, param: metricParam, comparator: comparator, threshold: threshold)
    }

    /// 转换成引擎认识的通用规则，让内置与自建挑战走同一条评估路径
    var asRule: UnlockRule {
        UnlockRule(
            id: ruleID ?? id.uuidString,
            kind: .challenge,
            name: title,
            detail: detail,
            icon: iconName,
            conditions: [condition],
            reward: RewardBundle(exp: rewardEXP, gold: rewardGold, titleID: rewardTitleID)
        )
    }

    static func fromRule(_ rule: UnlockRule) -> Challenge? {
        guard rule.kind == .challenge, let condition = rule.conditions.first else { return nil }
        return Challenge(
            title: rule.name,
            detail: rule.detail,
            iconName: rule.icon,
            metricKey: condition.metric,
            metricParam: condition.param,
            comparator: condition.comparator,
            threshold: condition.threshold,
            rewardEXP: rule.reward.exp,
            rewardGold: rule.reward.gold,
            rewardTitleID: rule.reward.titleID,
            ruleID: rule.id
        )
    }
}
