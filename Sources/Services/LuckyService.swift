import Foundation

struct FortuneEvent: Identifiable, Hashable, Sendable {
    var id = UUID()
    var icon: String
    var title: String
    var subtitle: String
}

/// 幸运日与幸运成长。数值全部来自 `fortune.json`，判定本身是纯函数。
@MainActor
final class LuckyService {
    private let config: GameConfig
    private let calendar: GameCalendar
    private(set) var pendingEvents: [FortuneEvent] = []

    init(config: GameConfig, calendar: GameCalendar) {
        self.config = config
        self.calendar = calendar
    }

    func consumeEvents() -> [FortuneEvent] {
        let events = pendingEvents
        pendingEvents.removeAll()
        return events
    }

    func activeFortune(for player: Player, on day: GameDay) -> FortuneTier? {
        guard player.fortuneRollDayValue == day.value, !player.activeFortuneID.isEmpty else { return nil }
        return config.fortune.tier(id: player.activeFortuneID)
    }

    /// 当天第一次完成任务时判定一次。已判定则返回已生效的命运（可能为 nil）。
    @discardableResult
    func rollDayIfNeeded(
        player: Player,
        on day: GameDay,
        chanceRoll: Double = Double.random(in: 0..<1),
        fortuneRoll: Double = Double.random(in: 0..<1)
    ) -> FortuneTier? {
        if player.fortuneRollDayValue == day.value {
            return activeFortune(for: player, on: day)
        }

        player.fortuneRollDayValue = day.value
        player.activeFortuneID = ""

        let luckyLevel = config.statCurve.level(forTotalEXP: player.luckyEXP)
        let chance = LuckyEngine.luckyDayChance(luckyLevel: luckyLevel, config: config.fortune)
        guard LuckyEngine.succeeds(roll: chanceRoll, chance: chance) else { return nil }
        guard let tier = LuckyEngine.pickFortune(roll: fortuneRoll, fortunes: config.fortune.fortunes) else { return nil }

        player.activeFortuneID = tier.id
        pendingEvents.append(
            FortuneEvent(
                icon: "leaf.fill",
                title: L10n.format("fortune.event.lucky_day", tier.localizedName),
                subtitle: tier.bonusGold > 0
                    ? L10n.format("fortune.event.bonus_gold", tier.bonusPercentText, tier.bonusGold)
                    : L10n.format("fortune.event.bonus", tier.bonusPercentText)
            )
        )
        return tier
    }

    @discardableResult
    func rollGrowth(
        player: Player,
        roll: Double = Double.random(in: 0..<1)
    ) -> Bool {
        let chance = config.fortune.luckyGrowthChance
        guard LuckyEngine.succeeds(roll: roll, chance: chance) else { return false }

        let xp = max(1, config.fortune.luckyXPOnGrowth)
        let before = player.luckyEXP
        player.luckyEXP += xp
        let newLevel = config.statCurve.level(forTotalEXP: player.luckyEXP)
        let oldLevel = config.statCurve.level(forTotalEXP: before)
        let subtitle: String
        if newLevel > oldLevel {
            subtitle = L10n.format("fortune.level_up", newLevel)
        } else {
            subtitle = L10n.format("fortune.xp", xp)
        }
        pendingEvents.append(
            FortuneEvent(icon: "sparkles", title: L10n.t("fortune.grew"), subtitle: subtitle)
        )
        return true
    }
}
