import Foundation
import SwiftData

/// 解锁记录。规则本身住在 JSON 里，数据库只记录"哪条规则在什么时候被解锁了"，
/// 这样调整规则文案或图标不需要迁移数据。
@Model
final class UnlockRecord {
    var id: UUID = UUID()
    var ruleID: String = ""
    var kindRaw: String = UnlockKind.achievement.rawValue
    var unlockedAt: Date = Date()
    var unlockedDayValue: Int = 0
    /// 新解锁的红点是否已被用户看过
    var isSeen: Bool = false

    init(ruleID: String, kind: UnlockKind, day: GameDay) {
        self.id = UUID()
        self.ruleID = ruleID
        self.kindRaw = kind.rawValue
        self.unlockedAt = Date()
        self.unlockedDayValue = day.value
    }

    var kind: UnlockKind {
        get { UnlockKind(rawValue: kindRaw) ?? .achievement }
        set { kindRaw = newValue.rawValue }
    }

    var unlockedDay: GameDay {
        get { GameDay(value: unlockedDayValue) }
        set { unlockedDayValue = newValue.value }
    }
}
