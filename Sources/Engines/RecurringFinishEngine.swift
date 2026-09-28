import Foundation

/// 远行收队时的档位。走得越久，归途奖励越高。
enum RecurringFinishTier: String, Sendable, CaseIterable {
    case spark
    case proven
    case veteran
    case legendary
    case mythic

    var localizationKey: String { "quest.finish.tier.\(rawValue)" }
    var title: String { L10n.t(localizationKey) }
}

struct RecurringFinishReward: Equatable, Sendable {
    var durationDays: Int
    var completions: Int
    var exp: Int
    var gold: Int
    var tier: RecurringFinishTier
}

/// 远行收队奖励。纯函数：持续天数是主因，途中完成次数只做加成。
enum RecurringFinishEngine {
    static func durationDays(from start: GameDay, to end: GameDay, calendar: GameCalendar) -> Int {
        guard end >= start else { return 1 }
        return max(1, calendar.daysBetween(start, end) + 1)
    }

    static func tier(for durationDays: Int) -> RecurringFinishTier {
        switch durationDays {
        case 365...: return .mythic
        case 100...: return .legendary
        case 30...: return .veteran
        case 7...: return .proven
        default: return .spark
        }
    }

    static func evaluate(durationDays: Int, completions: Int) -> RecurringFinishReward {
        let days = max(1, durationDays)
        let done = max(0, completions)
        var exp = 200 + days * 15 + min(done, days * 2) * 8
        if days >= 7 { exp += 150 }
        if days >= 30 { exp += 500 }
        if days >= 100 { exp += 1_800 }
        if days >= 365 { exp += 4_500 }
        let gold = Int((Double(exp) * 0.9).rounded())
        return RecurringFinishReward(
            durationDays: days,
            completions: done,
            exp: exp,
            gold: gold,
            tier: tier(for: days)
        )
    }
}
