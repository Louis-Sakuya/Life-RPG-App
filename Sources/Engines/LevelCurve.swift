import Foundation

struct LevelProgress: Hashable, Sendable {
    var level: Int
    /// 当前等级内已积累的经验
    var currentEXP: Int
    /// 升到下一级还需要的总经验（当前等级的档位宽度）
    var requiredEXP: Int
    var totalEXP: Int
    var isMaxLevel: Bool

    var progress: Double {
        guard requiredEXP > 0 else { return isMaxLevel ? 1.0 : 0.0 }
        return min(1.0, max(0.0, Double(currentEXP) / Double(requiredEXP)))
    }

    var remainingEXP: Int { max(0, requiredEXP - currentEXP) }
}

/// 等级曲线。玩家与技能共用这套实现，只是参数不同。
///
/// 等级不落库，永远由 `totalEXP` 推导。这样撤销任务回滚经验时等级会自动跟着回退，
/// 不需要额外处理"扣了经验但等级还留着"的漂移。
struct LevelCurve: Sendable {
    let config: BalanceConfig.LevelCurveConfig

    /// `cumulative[i]` 表示达到 `i + 1` 级所需的累计经验，`cumulative[0] == 0`
    private let cumulative: [Int]

    init(config: BalanceConfig.LevelCurveConfig) {
        self.config = config
        var accumulated = 0
        var table = [0]
        let maxLevel = max(2, config.maxLevel)
        for level in 1..<maxLevel {
            let requirement = config.base * pow(Double(level), config.exponent)
            accumulated += max(1, Int(requirement.rounded()))
            table.append(accumulated)
        }
        self.cumulative = table
    }

    var maxLevel: Int { cumulative.count }

    /// 从 `level` 升到 `level + 1` 需要的经验
    func requirement(forLevel level: Int) -> Int {
        guard level >= 1, level < maxLevel else { return 0 }
        return cumulative[level] - cumulative[level - 1]
    }

    /// 达到 `level` 所需的累计经验
    func totalEXPRequired(forLevel level: Int) -> Int {
        let index = min(max(level, 1), maxLevel) - 1
        return cumulative[index]
    }

    func progress(totalEXP: Int) -> LevelProgress {
        let exp = max(0, totalEXP)
        let level = level(forTotalEXP: exp)
        let isMax = level >= maxLevel
        let floorEXP = totalEXPRequired(forLevel: level)
        return LevelProgress(
            level: level,
            currentEXP: exp - floorEXP,
            requiredEXP: isMax ? 0 : requirement(forLevel: level),
            totalEXP: exp,
            isMaxLevel: isMax
        )
    }

    func level(forTotalEXP totalEXP: Int) -> Int {
        let exp = max(0, totalEXP)
        var low = 0
        var high = cumulative.count - 1
        var result = 0
        while low <= high {
            let mid = (low + high) / 2
            if cumulative[mid] <= exp {
                result = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return result + 1
    }

    /// 从 `oldEXP` 涨到 `newEXP` 期间跨过的等级，用于发放升级奖励
    func levelsGained(from oldEXP: Int, to newEXP: Int) -> [Int] {
        let oldLevel = level(forTotalEXP: oldEXP)
        let newLevel = level(forTotalEXP: newEXP)
        guard newLevel > oldLevel else { return [] }
        return Array((oldLevel + 1)...newLevel)
    }
}
