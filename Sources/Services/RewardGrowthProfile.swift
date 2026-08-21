import Foundation
import SwiftData

/// 把当前技能等级与属性等级打成奖励引擎能吃的快照。
struct RewardGrowthProfile: Sendable {
    var skillLevels: [UUID: Int]
    var skillAffinities: [UUID: [StatAffinity]]
    var statLevels: [CoreStatID: Int]

    static func make(
        shares: [SkillShare],
        player: Player,
        context: ModelContext,
        config: GameConfig
    ) -> RewardGrowthProfile {
        let lookup = SkillRepository(context: context).skills(ids: shares.map(\.skillID))
        let skillLevels = lookup.mapValues { config.skillCurve.level(forTotalEXP: $0.totalEXP) }
        let skillAffinities = lookup.mapValues(\.affinities)
        let statLevels = Dictionary(uniqueKeysWithValues: CoreStatID.allCases.map { stat in
            let trained = config.statCurve.level(forTotalEXP: player.exp(for: stat))
            return (stat, trained + player.allocatedPoints(for: stat))
        })
        return RewardGrowthProfile(
            skillLevels: skillLevels,
            skillAffinities: skillAffinities,
            statLevels: statLevels
        )
    }
}
