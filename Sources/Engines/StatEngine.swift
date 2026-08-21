import Foundation

/// 把技能经验按亲和度折算成核心属性经验。
/// Lucky 不在这里出现：它不能被训练，只走独立的命运判定。
enum StatEngine {
    static func distribute(skillEXP: [UUID: Int], skills: [UUID: SkillSnapshot]) -> [CoreStatID: Int] {
        var totals: [CoreStatID: Double] = [:]
        for (skillID, exp) in skillEXP where exp != 0 {
            guard let skill = skills[skillID] else { continue }
            let affinities = skill.affinities.filter { $0.weight > 0 }
            let weightSum = affinities.reduce(0.0) { $0 + $1.weight }
            guard weightSum > 0 else { continue }
            for affinity in affinities {
                totals[affinity.stat, default: 0] += Double(exp) * (affinity.weight / weightSum)
            }
        }
        return totals.mapValues { Int($0.rounded()) }.filter { $0.value != 0 }
    }
}

/// 引擎不得依赖 SwiftData，所以技能亲和只吃这个快照。
struct SkillSnapshot: Sendable {
    var id: UUID
    var affinities: [StatAffinity]
}
