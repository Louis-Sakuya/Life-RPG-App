import Foundation

/// 五个核心属性。描述「你正在成为怎样的人」，而不是某一个具体技能。
enum CoreStatID: String, CaseIterable, Codable, Identifiable, Sendable {
    case body
    case mind
    case life
    case social
    case creation

    var id: String { rawValue }

    var englishTitle: String {
        switch self {
        case .body: return "Body"
        case .mind: return "Mind"
        case .life: return "Life"
        case .social: return "Social"
        case .creation: return "Creation"
        }
    }

    var iconName: String {
        switch self {
        case .body: return "figure.run"
        case .mind: return "brain.head.profile"
        case .life: return "house.fill"
        case .social: return "person.2.fill"
        case .creation: return "paintpalette.fill"
        }
    }

    var colorHex: String {
        switch self {
        case .body: return "#E2603B"
        case .mind: return "#5B8DEF"
        case .life: return "#2FA36B"
        case .social: return "#E86A92"
        case .creation: return "#9A6BFF"
        }
    }
}

enum HiddenStatID: String, Sendable {
    case lucky

    var englishTitle: String { "Lucky" }
    var iconName: String { "leaf.fill" }
    var colorHex: String { "#C9A227" }
}

/// 技能对某个核心属性的经验亲和。一个技能可以喂养多个属性，权重合计 100%。
struct StatAffinity: Hashable, Sendable {
    var stat: CoreStatID
    var weight: Double

    init(stat: CoreStatID, weight: Double) {
        self.stat = stat
        self.weight = weight
    }

    init?(token: String) {
        let parts = token.split(separator: ":")
        guard parts.count == 2,
              let stat = CoreStatID(rawValue: String(parts[0])),
              let weight = Double(parts[1]) else { return nil }
        self.stat = stat
        self.weight = weight
    }

    var token: String { "\(stat.rawValue):\(weight)" }
}
