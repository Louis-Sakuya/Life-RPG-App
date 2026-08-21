import Foundation

/// 初始化流程里选定的技能草稿。在确认开始冒险之前不写入数据库。
struct OnboardingSkillDraft: Identifiable, Hashable, Sendable {
    static let maxCount = 5

    var id: UUID
    var catalogID: String
    var name: String
    var iconName: String
    var colorHex: String
    var categories: [String]
    var affinities: [StatAffinity]

    init(
        id: UUID = UUID(),
        catalogID: String = "",
        name: String,
        iconName: String,
        colorHex: String,
        categories: [String] = [],
        affinities: [StatAffinity] = []
    ) {
        self.id = id
        self.catalogID = catalogID
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.categories = categories
        self.affinities = affinities
    }

    static func fromPreset(_ preset: SkillPreset) -> OnboardingSkillDraft {
        OnboardingSkillDraft(
            catalogID: preset.id,
            name: preset.name,
            iconName: preset.icon,
            colorHex: preset.color,
            categories: preset.categories,
            affinities: preset.parsedAffinities
        )
    }

    var isPreset: Bool { !catalogID.isEmpty }

    var localizedName: String {
        if isPreset {
            return L10n.t("skill.\(catalogID).name", fallback: name)
        }
        return name
    }
}
