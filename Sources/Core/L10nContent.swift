import Foundation

extension CoreStatID {
    var title: String { L10n.t("stat.\(rawValue).title") }
    var summary: String { L10n.t("stat.\(rawValue).summary") }
    var definition: String { L10n.t("stat.\(rawValue).definition") }

    var domains: [String] {
        let count: Int
        switch self {
        case .body: count = 7
        case .mind: count = 8
        case .life: count = 6
        case .social: count = 8
        case .creation: count = 8
        }
        return (0..<count).map { L10n.t("stat.\(rawValue).domain.\($0)") }
    }
}

extension HiddenStatID {
    var title: String { L10n.t("stat.lucky.title") }
    var summary: String { L10n.t("stat.lucky.summary") }
    var definition: String { L10n.t("stat.lucky.definition") }
}

extension Skill {
    var localizedName: String {
        guard !catalogID.isEmpty else { return name }
        return L10n.t("skill.\(catalogID).name", fallback: name)
    }
}

extension LevelUpEvent {
    /// 弹层展示用。预设技能与属性跟当前语言走，自定义技能用玩家自己起的名字。
    var localizedSubjectName: String? {
        if let statID {
            return statID.title
        }
        guard let skillName else { return nil }
        if let catalogID, !catalogID.isEmpty {
            return L10n.t("skill.\(catalogID).name", fallback: skillName)
        }
        return skillName
    }
}

extension SkillPreset {
    var localizedName: String { L10n.t("skill.\(id).name", fallback: name) }
}

extension SkillCategory {
    var localizedName: String { L10n.t("skill.category.\(id)", fallback: name) }
}

extension FortuneTier {
    var localizedName: String { L10n.t("fortune.\(id).name", fallback: name) }
}

extension AppliedModifier {
    var localizedLabel: String { L10n.t("modifier.\(id).label", fallback: label) }
}

extension ShopItem {
    var localizedName: String { L10n.t("shop.\(id).name", fallback: name) }
    var localizedDetail: String { L10n.t("shop.\(id).detail", fallback: detail) }
}

extension UnlockRule {
    var localizedName: String { L10n.t("unlock.\(id).name", fallback: name) }
    var localizedDetail: String { L10n.t("unlock.\(id).detail", fallback: detail) }
}

extension ShopItemKind {
    var displayName: String { L10n.t("shop.\(rawValue)") }
}

extension UnlockKind {
    var displayName: String { L10n.t("unlock.kind.\(rawValue)") }
}

extension RewardSourceKind {
    var displayName: String { L10n.t("source.\(rawValue)") }
}

extension StatsRange {
    var title: String { L10n.t("stats.range.\(rawValue)") }
}
