import Foundation

/// 连续机制的唯一实现。任务、习惯、登录三处都调用它，
/// 避免"跨天判断"这种极易出错的逻辑散落成三份互相不一致的副本。
enum StreakEngine {

    /// 在 `day` 达成一次，推进连续状态。
    ///
    /// - 同一天重复达成不会重复计数
    /// - 与上次达成相隔恰好一天则连续 +1
    /// - 相隔超过一天则从 1 重新开始
    /// - 传入早于上次达成的日期视为补记，不改变当前连续数
    static func advance(_ state: StreakState, on day: GameDay, calendar: GameCalendar) -> StreakState {
        guard let last = state.lastDay else {
            return StreakState(current: 1, best: max(1, state.best), lastDay: day)
        }
        if day == last { return state }
        if day < last {
            return state
        }
        let gap = calendar.daysBetween(last, day)
        let current = gap == 1 ? state.current + 1 : 1
        return StreakState(current: current, best: max(current, state.best), lastDay: day)
    }

    /// 在 `day` 这一天检查连续是否已经断掉。用于每日结算时把过期的连续清零，
    /// 否则玩家会看到一个早已中断却仍显示为高位的数字。
    static func decayIfBroken(_ state: StreakState, today: GameDay, calendar: GameCalendar) -> StreakState {
        guard let last = state.lastDay, state.current > 0 else { return state }
        let gap = calendar.daysBetween(last, today)
        guard gap > 1 else { return state }
        return StreakState(current: 0, best: state.best, lastDay: last)
    }

    /// 撤销某一天的达成。只有当被撤销的正是最后一天时才需要回退，
    /// 更早的补记撤销不影响当前连续数。
    static func revert(_ state: StreakState, on day: GameDay, calendar: GameCalendar) -> StreakState {
        guard let last = state.lastDay, last == day, state.current > 0 else { return state }
        let newCurrent = state.current - 1
        let newLast = newCurrent > 0 ? calendar.adding(days: -1, to: day) : nil
        return StreakState(current: newCurrent, best: state.best, lastDay: newLast)
    }

    /// 连续天数对应的全局经验乘数，取满足条件的最高档
    static func multiplier(forDays days: Int, tiers: [BalanceConfig.StreakTier]) -> Double {
        var result = 1.0
        for tier in tiers.sorted(by: { $0.days < $1.days }) where days >= tier.days {
            result = tier.multiplier
        }
        return result
    }

    /// 距离下一档还差几天，用于在界面上给玩家一个明确的短期目标
    static func nextTier(forDays days: Int, tiers: [BalanceConfig.StreakTier]) -> BalanceConfig.StreakTier? {
        tiers.sorted(by: { $0.days < $1.days }).first { $0.days > days }
    }
}
