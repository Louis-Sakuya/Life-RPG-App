import Foundation
import SwiftData

/// 技能。用户可以无限自由创建，等级完全独立于玩家等级成长。
@Model
final class Skill {
    var id: UUID = UUID()
    var name: String = ""
    var iconName: String = "star.fill"
    /// 十六进制颜色，例如 #5B8DEF
    var colorHex: String = "#5B8DEF"
    /// 经验的唯一真相，等级由 `LevelCurve` 推导
    var totalEXP: Int = 0
    var createdAt: Date = Date()
    var sortOrder: Int = 0
    var isArchived: Bool = false

    init(name: String, iconName: String = "star.fill", colorHex: String = "#5B8DEF", sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.createdAt = Date()
        self.sortOrder = sortOrder
    }
}
