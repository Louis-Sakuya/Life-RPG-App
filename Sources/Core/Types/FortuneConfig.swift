import Foundation

struct FortuneTier: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var name: String
    var englishName: String
    var weight: Double
    /// 经验加成，0.10 表示 +10%
    var xpBonus: Double
    var goldBonus: Double
    var bonusGold: Int
    var bonusEXP: Int

    var xpMultiplier: Double { 1 + xpBonus }
    var goldMultiplier: Double { 1 + goldBonus }

    var bonusPercentText: String {
        let percent = Int((xpBonus * 100).rounded())
        return "+\(percent)%"
    }
}

struct FortuneConfig: Codable, Sendable {
    var version: Int
    /// 完成任务后幸运成长的概率
    var luckyGrowthChance: Double
    var luckyXPOnGrowth: Int
    var luckyDay: LuckyDayConfig
    var fortunes: [FortuneTier]

    struct LuckyDayConfig: Codable, Sendable {
        var baseChance: Double
        var chancePerLuckyLevel: Double
        var maxChance: Double
    }

    func tier(id: String) -> FortuneTier? {
        fortunes.first { $0.id == id }
    }

    static let fallback = FortuneConfig(
        version: 0,
        luckyGrowthChance: 0.002,
        luckyXPOnGrowth: 18,
        luckyDay: .init(baseChance: 0.03, chancePerLuckyLevel: 0.005, maxChance: 0.18),
        fortunes: [
            .init(id: "fortune_1", name: "小吉", englishName: "Fortune I", weight: 50, xpBonus: 0.10, goldBonus: 0.10, bonusGold: 0, bonusEXP: 0),
            .init(id: "fortune_2", name: "中吉", englishName: "Fortune II", weight: 30, xpBonus: 0.25, goldBonus: 0.25, bonusGold: 0, bonusEXP: 0),
            .init(id: "fortune_3", name: "大吉", englishName: "Fortune III", weight: 15, xpBonus: 0.50, goldBonus: 0.50, bonusGold: 0, bonusEXP: 0),
            .init(id: "fortune_4", name: "天命", englishName: "Fortune IV", weight: 5, xpBonus: 1.0, goldBonus: 1.0, bonusGold: 50, bonusEXP: 0)
        ]
    )
}
