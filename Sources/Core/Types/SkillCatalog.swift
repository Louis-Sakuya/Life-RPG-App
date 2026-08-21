import Foundation

struct SkillCategory: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var name: String
    var icon: String
}

struct SkillPreset: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var name: String
    var aliases: [String]
    var icon: String
    var color: String
    var categories: [String]
    var affinities: [String: Double]

    enum CodingKeys: String, CodingKey {
        case id, name, aliases, icon, color, categories, affinities
    }

    init(
        id: String,
        name: String,
        aliases: [String] = [],
        icon: String,
        color: String,
        categories: [String],
        affinities: [String: Double]
    ) {
        self.id = id
        self.name = name
        self.aliases = aliases
        self.icon = icon
        self.color = color
        self.categories = categories
        self.affinities = affinities
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        aliases = try container.decodeIfPresent([String].self, forKey: .aliases) ?? []
        icon = try container.decode(String.self, forKey: .icon)
        color = try container.decode(String.self, forKey: .color)
        categories = try container.decode([String].self, forKey: .categories)
        affinities = try container.decode([String: Double].self, forKey: .affinities)
    }

    var parsedAffinities: [StatAffinity] {
        affinities.compactMap { key, value in
            guard let stat = CoreStatID(rawValue: key), value > 0 else { return nil }
            return StatAffinity(stat: stat, weight: value)
        }
        .sorted { $0.stat.rawValue < $1.stat.rawValue }
    }

    var primaryStat: CoreStatID {
        parsedAffinities.max(by: { $0.weight < $1.weight })?.stat ?? .mind
    }

    func matches(_ name: String) -> Bool {
        let folded = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if self.name.lowercased() == folded { return true }
        return aliases.contains { $0.lowercased() == folded }
    }
}

struct SkillCatalog: Codable, Sendable {
    var version: Int
    var categories: [SkillCategory]
    var skills: [SkillPreset]

    func category(id: String) -> SkillCategory? {
        categories.first { $0.id == id }
    }

    func preset(id: String) -> SkillPreset? {
        skills.first { $0.id == id }
    }

    func preset(matchingName name: String) -> SkillPreset? {
        skills.first { $0.matches(name) }
    }

    func presets(for stat: CoreStatID) -> [SkillPreset] {
        skills.filter { $0.primaryStat == stat }
    }

    static let fallback = SkillCatalog(
        version: 0,
        categories: [
            .init(id: "fitness", name: "体能", icon: "figure.run"),
            .init(id: "knowledge", name: "知识", icon: "book.fill")
        ],
        skills: [
            .init(
                id: "programming",
                name: "Programming",
                aliases: ["编程"],
                icon: "chevron.left.forwardslash.chevron.right",
                color: "#5B8DEF",
                categories: ["knowledge"],
                affinities: ["mind": 0.7, "creation": 0.3]
            )
        ]
    )
}
