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

/// 当前生效的配色。主题是商店商品，因此调色板来自 `shop_items.json` 的 payload，
/// 新增主题不需要改任何代码。
struct ThemePalette: Equatable {
    var accent: Color
    var secondary: Color

    static let `default` = ThemePalette(accent: Color(hex: "#5B8DEF"), secondary: Color(hex: "#8E7CFF"))

    init(accent: Color, secondary: Color) {
        self.accent = accent
        self.secondary = secondary
    }

    init(item: ShopItem?) {
        self.accent = Color(hex: item?.accentHex ?? "#5B8DEF")
        self.secondary = Color(hex: item?.secondaryHex ?? "#8E7CFF")
    }

    var gradient: LinearGradient {
        LinearGradient(colors: [accent, secondary], startPoint: .topLeading, endPoint: .bottomTrailing)
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
