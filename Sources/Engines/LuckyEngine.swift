import Foundation

/// 幸运成长与幸运日判定。全部是纯函数，随机数由调用方注入，因此可以单测。
enum LuckyEngine {
    /// `roll` 落在 `[0, chance)` 时成功。chance 为 0 永远失败，为 1 几乎总成功。
    static func succeeds(roll: Double, chance: Double) -> Bool {
        let clamped = min(1, max(0, chance))
        guard clamped > 0 else { return false }
        return roll < clamped
    }

    static func luckyDayChance(luckyLevel: Int, config: FortuneConfig) -> Double {
        let extra = Double(max(0, luckyLevel - 1)) * config.luckyDay.chancePerLuckyLevel
        return min(config.luckyDay.maxChance, max(0, config.luckyDay.baseChance + extra))
    }

    /// `roll` 是 0...1，按权重抽一条命运档位。
    static func pickFortune(roll: Double, fortunes: [FortuneTier]) -> FortuneTier? {
        let total = fortunes.reduce(0.0) { $0 + max(0, $1.weight) }
        guard total > 0, let first = fortunes.first else { return fortunes.first }
        let clamped = min(1, max(0, roll)) * total
        var cursor = 0.0
        for tier in fortunes {
            cursor += max(0, tier.weight)
            if clamped < cursor { return tier }
        }
        return fortunes.last ?? first
    }
}
