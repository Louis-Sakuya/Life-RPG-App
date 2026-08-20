import Foundation

/// 连续状态。任务、习惯、登录三套连续机制共用这一个值类型，
/// 推进逻辑集中在 `StreakEngine`，避免三处各写一份跨天判断。
struct StreakState: Codable, Hashable, Sendable {
    var current: Int
    var best: Int
    var lastDay: GameDay?

    init(current: Int = 0, best: Int = 0, lastDay: GameDay? = nil) {
        self.current = current
        self.best = best
        self.lastDay = lastDay
    }

    static let empty = StreakState()
}
