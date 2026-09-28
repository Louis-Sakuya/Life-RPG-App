import Foundation

enum ShopItemKind: String, Codable, CaseIterable, Sendable {
    case consumable
    case theme
    case avatarFrame
    case background
    case effect
    case sound
    case pet

    var iconName: String {
        switch self {
        case .theme: return "paintpalette.fill"
        case .avatarFrame: return "person.crop.circle.badge.checkmark"
        case .background: return "photo.fill"
        case .effect: return "sparkles"
        case .sound: return "speaker.wave.2.fill"
        case .pet: return "pawprint.fill"
        case .consumable: return "seal.fill"
        }
    }
}

enum ShopItemID {
    static let leaveWard = "consumable_ward"
    static let streakShield = "consumable_shield"
}

/// 商店以装饰品为主。消耗品（请假卡 / 保险卡）是明确的功能例外，
/// 只改变日程时钟或连胜保护，不直接加减任务经验。
struct ShopItem: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var kind: ShopItemKind
    var name: String
    var detail: String
    var icon: String
    var price: Int
    var requiredLevel: Int
    var payload: [String: String]

    init(
        id: String,
        kind: ShopItemKind,
        name: String,
        detail: String = "",
        icon: String = "bag.fill",
        price: Int = 0,
        requiredLevel: Int = 1,
        payload: [String: String] = [:]
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.detail = detail
        self.icon = icon
        self.price = price
        self.requiredLevel = requiredLevel
        self.payload = payload
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, name, detail, icon, price, requiredLevel, payload
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        kind = try container.decode(ShopItemKind.self, forKey: .kind)
        name = try container.decode(String.self, forKey: .name)
        detail = try container.decodeIfPresent(String.self, forKey: .detail) ?? ""
        icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? "bag.fill"
        price = try container.decodeIfPresent(Int.self, forKey: .price) ?? 0
        requiredLevel = try container.decodeIfPresent(Int.self, forKey: .requiredLevel) ?? 1
        payload = try container.decodeIfPresent([String: String].self, forKey: .payload) ?? [:]
    }

    var accentHex: String? { payload["accent"] }
    var secondaryHex: String? { payload["secondary"] }
    var atmosphereID: String { payload["atmosphere"] ?? "default" }
    var styleID: String { payload["style"] ?? "" }
    var cueID: String { payload["cue"] ?? "" }
    var packID: String { payload["pack"] ?? "" }
}

struct ShopCatalog: Codable, Sendable {
    var version: Int
    var items: [ShopItem]

    func items(of kind: ShopItemKind) -> [ShopItem] {
        items.filter { $0.kind == kind }
    }

    func item(id: String) -> ShopItem? {
        items.first { $0.id == id }
    }

    static let fallback = ShopCatalog(version: 0, items: [
        ShopItem(id: "theme_default", kind: .theme, name: "起始之地", price: 0, payload: ["accent": "#5B8DEF", "secondary": "#8E7CFF"])
    ])
}
