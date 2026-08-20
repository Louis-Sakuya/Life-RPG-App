import Foundation

/// `Resources/Config/balance.json` 的映射。所有数值都来自这里，代码里不出现魔法数字。
struct BalanceConfig: Codable, Sendable {
    struct DurationFactor: Codable, Sendable {
        var bonusPerHour: Double
        var min: Double
        var max: Double
    }

    struct Clamp: Codable, Sendable {
        var min: Double
        var max: Double
    }

    struct LevelCurveConfig: Codable, Sendable {
        var base: Double
        var exponent: Double
        var maxLevel: Int
    }

    struct StreakTier: Codable, Sendable {
        var days: Int
        var multiplier: Double
    }

    struct LevelUpReward: Codable, Sendable {
        var goldBase: Int
        var goldPerLevel: Int
    }

    struct HabitReward: Codable, Sendable {
        var baseEXP: Int
        var baseGold: Int
    }

    var version: Int
    var goldRatio: Double
    var difficultyBaseEXP: [String: Double]
    var durationFactor: DurationFactor
    var multiplierClamp: Clamp
    var playerCurve: LevelCurveConfig
    var skillCurve: LevelCurveConfig
    var streakTiers: [StreakTier]
    var levelUpReward: LevelUpReward
    var habitReward: HabitReward

    func baseEXP(for difficulty: QuestDifficulty) -> Double {
        difficultyBaseEXP[String(difficulty.rawValue)] ?? 20
    }

    /// 内置兜底值。配置文件缺失或损坏时应用仍然可用，只是回到默认平衡。
    static let fallback = BalanceConfig(
        version: 0,
        goldRatio: 0.5,
        difficultyBaseEXP: ["1": 10, "2": 20, "3": 35, "4": 55, "5": 80],
        durationFactor: .init(bonusPerHour: 0.5, min: 1.0, max: 3.0),
        multiplierClamp: .init(min: 0.2, max: 3.0),
        playerCurve: .init(base: 100, exponent: 1.5, maxLevel: 100),
        skillCurve: .init(base: 60, exponent: 1.6, maxLevel: 100),
        streakTiers: [
            .init(days: 7, multiplier: 1.1),
            .init(days: 30, multiplier: 1.2),
            .init(days: 100, multiplier: 1.5)
        ],
        levelUpReward: .init(goldBase: 50, goldPerLevel: 10),
        habitReward: .init(baseEXP: 12, baseGold: 6)
    )
}

/// 单条奖励加成。`group` 是关键字段：同组内互斥，只有一条会生效，
/// 避免"提前规划 +20%"与"当天临时 -50%"这类语义矛盾的加成同时叠加。
struct RewardModifier: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var group: String
    var value: Double
    var label: String
    var detail: String
}

struct ModifierConfig: Codable, Sendable {
    var version: Int
    var modifiers: [RewardModifier]

    func modifier(id: String) -> RewardModifier? {
        modifiers.first { $0.id == id }
    }

    static let fallback = ModifierConfig(version: 0, modifiers: [
        .init(id: ModifierID.plannedAhead, group: "planning", value: 0.2, label: "提前规划", detail: ""),
        .init(id: ModifierID.sameDay, group: "planning", value: -0.5, label: "当天临时", detail: ""),
        .init(id: ModifierID.onTime, group: "timeliness", value: 0.2, label: "按时完成", detail: ""),
        .init(id: ModifierID.overdue, group: "timeliness", value: -0.3, label: "延期完成", detail: ""),
        .init(id: ModifierID.fiveStar, group: "priority", value: 0.3, label: "五星任务", detail: ""),
        .init(id: ModifierID.consecutive, group: "continuity", value: 0.1, label: "连续完成", detail: "")
    ])
}

/// 加成的触发条件属于业务规则，写在代码里；加成的数值与分组属于平衡参数，写在 JSON 里。
/// 这两者的边界就是这组常量。
enum ModifierID {
    static let plannedAhead = "planned_ahead"
    static let sameDay = "same_day"
    static let onTime = "on_time"
    static let overdue = "overdue"
    static let fiveStar = "five_star"
    static let consecutive = "consecutive"
}
