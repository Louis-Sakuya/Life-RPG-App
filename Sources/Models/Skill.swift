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
    /// 预设技能目录 id，自定义技能为空
    var catalogID: String = ""
    var categoryTokens: [String] = []
    /// `body:0.7` 形式，一个技能可以喂养多个核心属性
    var affinityTokens: [String] = []

    init(name: String, iconName: String = "star.fill", colorHex: String = "#5B8DEF", sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.createdAt = Date()
        self.sortOrder = sortOrder
    }

    var categories: [String] {
        get { categoryTokens }
        set { categoryTokens = newValue }
    }

    var affinities: [StatAffinity] {
        get { affinityTokens.compactMap(StatAffinity.init(token:)) }
        set { affinityTokens = newValue.map(\.token) }
    }

    var primaryStat: CoreStatID? {
        affinities.max(by: { $0.weight < $1.weight })?.stat
    }

    var snapshot: SkillSnapshot {
        SkillSnapshot(id: id, affinities: affinities)
    }

    func apply(preset: SkillPreset) {
        catalogID = preset.id
        name = preset.name
        iconName = preset.icon
        colorHex = preset.color
        categoryTokens = preset.categories
        affinities = preset.parsedAffinities
    }
}
