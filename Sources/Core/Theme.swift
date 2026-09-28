import SwiftUI

extension Color {
    /// 十六进制颜色。配置表与技能颜色都以 `#RRGGBB` 字符串存储，
    /// 这样调色不需要改代码，也不依赖 Asset Catalog。
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red, green, blue, alpha: Double
        switch cleaned.count {
        case 3:
            red = Double((value >> 8) & 0xF) / 15
            green = Double((value >> 4) & 0xF) / 15
            blue = Double(value & 0xF) / 15
            alpha = 1
        case 6:
            red = Double((value >> 16) & 0xFF) / 255
            green = Double((value >> 8) & 0xFF) / 255
            blue = Double(value & 0xFF) / 255
            alpha = 1
        case 8:
            red = Double((value >> 24) & 0xFF) / 255
            green = Double((value >> 16) & 0xFF) / 255
            blue = Double((value >> 8) & 0xFF) / 255
            alpha = Double(value & 0xFF) / 255
        default:
            red = 0.36
            green = 0.55
            blue = 0.94
            alpha = 1
        }
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

enum ThemeAtmosphere: String, Equatable, Sendable {
    case `default`
    case forest
    case ember
    case midnight
    case sakura
    case gold
}

/// 当前生效的配色。主题是商店商品，因此调色板来自 `shop_items.json` 的 payload，
/// 新增主题不需要改任何代码。
struct ThemePalette: Equatable {
    var accent: Color
    var secondary: Color
    var atmosphere: ThemeAtmosphere
    var themeID: String

    static let `default` = ThemePalette(
        accent: Color(hex: "#5B8DEF"),
        secondary: Color(hex: "#8E7CFF"),
        atmosphere: .default,
        themeID: "theme_default"
    )

    init(accent: Color, secondary: Color, atmosphere: ThemeAtmosphere = .default, themeID: String = "theme_default") {
        self.accent = accent
        self.secondary = secondary
        self.atmosphere = atmosphere
        self.themeID = themeID
    }

    init(item: ShopItem?) {
        let resolved = item?.kind == .theme ? item : nil
        self.accent = Color(hex: resolved?.accentHex ?? "#5B8DEF")
        self.secondary = Color(hex: resolved?.secondaryHex ?? "#8E7CFF")
        self.atmosphere = ThemeAtmosphere(rawValue: resolved?.atmosphereID ?? "default") ?? .default
        self.themeID = resolved?.id ?? "theme_default"
    }

    var gradient: LinearGradient {
        LinearGradient(colors: [accent, secondary], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var ornateColors: [Color] {
        switch atmosphere {
        case .gold:
            return [Color(hex: "#F0CE6A"), accent, Color(hex: "#8A6A12")]
        case .ember:
            return [secondary.opacity(0.95), accent, Color(hex: "#7A2E18")]
        default:
            return [Color(hex: "#E8D5A3"), accent.opacity(0.85), Color(hex: "#C9A227").opacity(0.7)]
        }
    }

    var plateFillOpacity: Double {
        atmosphere == .gold ? 0.22 : 0.16
    }
}

private struct ThemePaletteKey: EnvironmentKey {
    static let defaultValue = ThemePalette.default
}

extension EnvironmentValues {
    var palette: ThemePalette {
        get { self[ThemePaletteKey.self] }
        set { self[ThemePaletteKey.self] = newValue }
    }
}

enum AppMetrics {
    static let cardCornerRadius: CGFloat = 16
    static let cardPadding: CGFloat = 14
    static let sectionSpacing: CGFloat = 18
}
