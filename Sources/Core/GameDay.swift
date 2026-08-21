import Foundation

/// 游戏内的"一天"。内部表示为 `yyyyMMdd` 形式的整数，因此可以直接用于排序、
/// 比较以及 SwiftData 的谓词查询，而不需要处理 `Date` 的时区与时刻问题。
///
/// 注意：一个 `GameDay` 的真实起止时刻由 `GameCalendar.dayStartHour` 决定，
/// 默认凌晨 4 点。凌晨 1 点完成的任务属于前一个 `GameDay`。
struct GameDay: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    /// yyyyMMdd，例如 2026 年 8 月 4 日为 20260804
    let value: Int

    init(value: Int) {
        self.value = value
    }

    init(year: Int, month: Int, day: Int) {
        self.value = year * 10_000 + month * 100 + day
    }

    var year: Int { value / 10_000 }
    var month: Int { (value / 100) % 100 }
    var day: Int { value % 100 }

    var dateComponents: DateComponents {
        DateComponents(year: year, month: month, day: day)
    }

    static func < (lhs: GameDay, rhs: GameDay) -> Bool {
        lhs.value < rhs.value
    }

    var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// 用于列表分组标题等场景的短标签
    var shortLabel: String {
        L10n.format("date.md", month, day)
    }

    static let distantPast = GameDay(value: 0)
}
