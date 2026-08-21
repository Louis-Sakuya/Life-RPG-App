import Foundation

/// 技能栏位、属性加速技能经验、技能等级加速任务奖励。全部是纯函数，方便单测。
enum ProgressionEngine {
    /// `level` 为 1 时乘数是 1；之后每级加 `perLevel`，并夹在 `[1, max]`。
    static func bonus(level: Int, perLevel: Double, cap: Double) -> Double {
        let raw = 1.0 + Double(Swift.max(0, level - 1)) * Swift.max(0, perLevel)
        let ceiling = Swift.max(1.0, cap)
        return min(ceiling, Swift.max(1.0, raw))
    }

    /// 任务关联技能的等级越高，整笔任务经验与金币越高。按经验分配加权平均。
    static func questRewardMultiplier(
        shares: [SkillShare],
        levels: [UUID: Int],
        perLevel: Double,
        cap: Double
    ) -> Double {
        let active = shares.filter { $0.expShare > 0 }
        let totalShare = active.reduce(0.0) { $0 + $1.expShare }
        guard totalShare > 0 else { return 1 }
        let weighted = active.reduce(0.0) { sum, share in
            sum + share.expShare * bonus(level: levels[share.skillID] ?? 1, perLevel: perLevel, cap: cap)
        }
        return weighted / totalShare
    }

    /// 技能匹配的核心属性越高，该技能拿到的经验涨得越快。按亲和度加权。
    static func skillXPMultiplier(
        affinities: [StatAffinity],
        statLevels: [CoreStatID: Int],
        perLevel: Double,
        cap: Double
    ) -> Double {
        let active = affinities.filter { $0.weight > 0 }
        let weightSum = active.reduce(0.0) { $0 + $1.weight }
        guard weightSum > 0 else { return 1 }
        let weighted = active.reduce(0.0) { sum, affinity in
            sum + affinity.weight * bonus(
                level: statLevels[affinity.stat] ?? 1,
                perLevel: perLevel,
                cap: cap
            )
        }
        return weighted / weightSum
    }
}
