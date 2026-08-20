import Foundation

/// 所有统计量的扁平快照。解锁引擎只认识这个结构，因此它与数据库完全解耦，
/// 未来接入 AI 助手时也可以直接复用它作为只读输入。
struct MetricsSnapshot: Sendable {
    var scalars: [String: Double] = [:]
    /// 技能名 -> 等级
    var skillLevels: [String: Double] = [:]
    /// 习惯名 -> 当前连续天数
    var habitStreaks: [String: Double] = [:]

    func value(metric: String, param: String?) -> Double? {
        switch metric {
        case MetricKey.skillLevel:
            guard let param else { return skillLevels.values.max() ?? 0 }
            return skillLevels[param] ?? 0
        case MetricKey.habitStreak:
            guard let param else { return habitStreaks.values.max() ?? 0 }
            return habitStreaks[param] ?? 0
        default:
            return scalars[metric]
        }
    }
}

/// 成就、称号、挑战共用的评估引擎。纯函数，没有任何副作用。
///
/// 新增一条解锁内容只需要往 `unlock_rules.json` 加一行，零代码改动。
/// 这是整套架构里最重要的一个扩展点：否则每加一个成就都要改一次代码。
enum UnlockEngine {

    static func isSatisfied(_ condition: UnlockCondition, snapshot: MetricsSnapshot) -> Bool {
        guard let value = snapshot.value(metric: condition.metric, param: condition.param) else { return false }
        return condition.comparator.matches(value, condition.threshold)
    }

    static func isSatisfied(_ rule: UnlockRule, snapshot: MetricsSnapshot) -> Bool {
        guard !rule.conditions.isEmpty else { return false }
        return rule.conditions.allSatisfy { isSatisfied($0, snapshot: snapshot) }
    }

    /// 返回本次新满足、且此前尚未解锁的规则
    static func evaluate(
        snapshot: MetricsSnapshot,
        rules: [UnlockRule],
        unlockedIDs: Set<String>
    ) -> [UnlockRule] {
        rules.filter { !unlockedIDs.contains($0.id) && isSatisfied($0, snapshot: snapshot) }
    }

    /// 0...1 的完成进度。挑战的进度条直接用它算出，因此不需要额外存储进度字段。
    static func progress(of rule: UnlockRule, snapshot: MetricsSnapshot) -> Double {
        guard !rule.conditions.isEmpty else { return 0 }
        let ratios = rule.conditions.map { progress(of: $0, snapshot: snapshot) }
        return ratios.min() ?? 0
    }

    static func progress(of condition: UnlockCondition, snapshot: MetricsSnapshot) -> Double {
        guard let value = snapshot.value(metric: condition.metric, param: condition.param) else { return 0 }
        switch condition.comparator {
        case .gte:
            guard condition.threshold > 0 else { return value >= 0 ? 1 : 0 }
            return min(1, max(0, value / condition.threshold))
        case .lte, .eq:
            // 这类条件没有连续的进度语义，只有满足与不满足
            return condition.comparator.matches(value, condition.threshold) ? 1 : 0
        }
    }

    /// 当前值与阈值，用于在界面上展示 "37 / 100" 这样的文本
    static func progressText(of rule: UnlockRule, snapshot: MetricsSnapshot) -> String? {
        guard let condition = rule.conditions.first,
              condition.comparator == .gte,
              let value = snapshot.value(metric: condition.metric, param: condition.param) else { return nil }
        return "\(Int(value)) / \(Int(condition.threshold))"
    }
}
