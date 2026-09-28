import SwiftUI

/// 主题氛围 + 商店背景。叠在系统分组底色上，不强制深色皮肤，避免把暗黑模式打穿。
struct AtmosphereCanvas: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
            palette.accent.opacity(palette.atmosphere == .gold ? 0.14 : 0.09)
            AtmosphereDecor(atmosphere: palette.atmosphere, accent: palette.accent, secondary: palette.secondary)
            if let style = store.equippedBackgroundStyle {
                ShopBackgroundDecor(style: style)
            }
        }
        .ignoresSafeArea()
    }
}

struct AtmosphereDecor: View {
    var atmosphere: ThemeAtmosphere
    var accent: Color
    var secondary: Color

    var body: some View {
        Group {
            switch atmosphere {
            case .default:
                defaultWash
            case .forest:
                forestWash
            case .ember:
                emberWash
            case .midnight:
                midnightWash
            case .sakura:
                sakuraWash
            case .gold:
                goldWash
            }
        }
        .allowsHitTesting(false)
    }

    private var defaultWash: some View {
        RadialGradient(colors: [accent.opacity(0.16), .clear], center: .topLeading, startRadius: 20, endRadius: 280)
    }

    private var forestWash: some View {
        ZStack {
            RadialGradient(colors: [accent.opacity(0.22), .clear], center: .bottomLeading, startRadius: 40, endRadius: 340)
            ForEach(0..<8, id: \.self) { index in
                Image(systemName: "leaf.fill")
                    .font(.system(size: leafSize(index)))
                    .foregroundStyle(accent.opacity(0.18))
                    .offset(leafOffset(index))
                    .rotationEffect(.degrees(Double(index) * 28))
            }
        }
    }

    private var emberWash: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#E2603B").opacity(0.22), .clear], startPoint: .bottom, endPoint: .center)
            ForEach(0..<12, id: \.self) { index in
                Circle()
                    .fill(secondary.opacity(0.22))
                    .frame(width: emberSize(index), height: emberSize(index))
                    .offset(emberOffset(index))
                    .blur(radius: 0.4)
            }
        }
    }

    private var midnightWash: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#1B1464").opacity(0.28), .clear], startPoint: .top, endPoint: .bottom)
            ForEach(0..<18, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(starOpacity(index)))
                    .frame(width: starSize(index), height: starSize(index))
                    .offset(starOffset(index))
            }
        }
    }

    private var sakuraWash: some View {
        ZStack {
            RadialGradient(colors: [accent.opacity(0.20), .clear], center: .top, startRadius: 10, endRadius: 300)
            ForEach(0..<7, id: \.self) { index in
                Capsule()
                    .fill(secondary.opacity(0.28))
                    .frame(width: 10, height: 16)
                    .rotationEffect(.degrees(Double(index) * 18 - 30))
                    .offset(petalOffset(index))
            }
        }
    }

    private var goldWash: some View {
        ZStack {
            RadialGradient(colors: [accent.opacity(0.28), .clear], center: .top, startRadius: 10, endRadius: 260)
            LinearGradient(
                colors: [Color(hex: "#F0CE6A").opacity(0.12), .clear, Color(hex: "#D4A017").opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func leafSize(_ index: Int) -> CGFloat { CGFloat(12 + (index % 3) * 6) }
    private func emberSize(_ index: Int) -> CGFloat { CGFloat(3 + index % 4) }
    private func starSize(_ index: Int) -> CGFloat { CGFloat(1.5 + Double(index % 3)) }
    private func starOpacity(_ index: Int) -> Double { index.isMultiple(of: 3) ? 0.35 : 0.16 }

    private func leafOffset(_ index: Int) -> CGSize {
        let xs: [CGFloat] = [-140, 90, 150, -60, 40, -170, 120, -20]
        let ys: [CGFloat] = [-180, -90, 40, 160, 220, 80, -40, 130]
        return CGSize(width: xs[index % xs.count], height: ys[index % ys.count])
    }

    private func emberOffset(_ index: Int) -> CGSize {
        CGSize(width: CGFloat((index * 37) % 220) - 110, height: CGFloat(80 + (index * 19) % 160))
    }

    private func starOffset(_ index: Int) -> CGSize {
        CGSize(width: CGFloat((index * 53) % 300) - 150, height: CGFloat((index * 41) % 340) - 180)
    }

    private func petalOffset(_ index: Int) -> CGSize {
        let xs: [CGFloat] = [-90, 70, 140, -40, 20, -130, 100]
        let ys: [CGFloat] = [-160, -40, 70, 150, -90, 40, 200]
        return CGSize(width: xs[index % xs.count], height: ys[index % ys.count])
    }
}

struct ShopBackgroundDecor: View {
    var style: String

    var body: some View {
        switch style {
        case "parchment":
            ParchmentGrain()
        case "aurora":
            AuroraWash()
        default:
            EmptyView()
        }
    }
}

private struct ParchmentGrain: View {
    var body: some View {
        Canvas { context, size in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Color(hex: "#C9A227").opacity(0.07))
            )
            for row in stride(from: 18.0, to: size.height, by: 22) {
                var line = Path()
                line.move(to: CGPoint(x: 12, y: row))
                line.addLine(to: CGPoint(x: size.width - 12, y: row))
                context.stroke(line, with: .color(Color(hex: "#8A6A12").opacity(0.05)), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct AuroraWash: View {
    @State private var phase = false

    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color(hex: "#3EC1B3").opacity(0.22))
                .frame(width: 280, height: 140)
                .blur(radius: 28)
                .offset(x: phase ? 40 : -50, y: -120)
            Ellipse()
                .fill(Color(hex: "#9A6BFF").opacity(0.16))
                .frame(width: 240, height: 120)
                .blur(radius: 32)
                .offset(x: phase ? -30 : 60, y: -40)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 6.5).repeatForever(autoreverses: true)) {
                phase = true
            }
        }
        .allowsHitTesting(false)
    }
}

struct OrnateBorder: View {
    var cornerRadius: CGFloat
    var colors: [Color]
    var lineWidth: CGFloat = 1.4

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: lineWidth
            )
            .overlay {
                GeometryReader { geo in
                    let inset: CGFloat = 7
                    ZStack {
                        cornerMark.position(x: inset, y: inset)
                        cornerMark.rotationEffect(.degrees(90)).position(x: geo.size.width - inset, y: inset)
                        cornerMark.rotationEffect(.degrees(180)).position(x: geo.size.width - inset, y: geo.size.height - inset)
                        cornerMark.rotationEffect(.degrees(270)).position(x: inset, y: geo.size.height - inset)
                    }
                }
            }
            .allowsHitTesting(false)
    }

    private var cornerMark: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 8))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 8, y: 0))
        }
        .stroke(colors.first ?? Color(hex: "#C9A227"), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
        .frame(width: 8, height: 8)
    }
}

struct AvatarFrameOverlay: View {
    var style: String
    var color: Color
    var size: CGFloat

    var body: some View {
        let outer = size + 8
        ZStack {
            switch style {
            case "silver":
                Circle().strokeBorder(color.opacity(0.95), lineWidth: 3)
                    .frame(width: outer, height: outer)
                Circle().strokeBorder(Color.white.opacity(0.55), lineWidth: 1)
                    .frame(width: size + 2, height: size + 2)
            case "gold":
                Circle()
                    .fill(color.opacity(0.28))
                    .frame(width: outer + 8, height: outer + 8)
                    .blur(radius: 6)
                Circle().strokeBorder(color, lineWidth: 3.4)
                    .frame(width: outer, height: outer)
                Circle().strokeBorder(Color(hex: "#F0CE6A").opacity(0.8), lineWidth: 1)
                    .frame(width: size + 1, height: size + 1)
            case "mythic":
                MythicAvatarRing(color: color, size: size)
            default:
                Circle().strokeBorder(color, lineWidth: 3)
                    .frame(width: outer, height: outer)
            }
        }
        .frame(width: outer + 10, height: outer + 10)
        .allowsHitTesting(false)
    }
}

/// 圆形光环按墙上时钟旋转，不依赖 onAppear，切 Tab 回来也会接着转。
private struct MythicAvatarRing: View {
    var color: Color
    var size: CGFloat

    private let period: TimeInterval = 8

    var body: some View {
        let outer = size + 8
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let turn = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
            let angle = turn * 360
            ZStack {
                Circle()
                    .fill(color.opacity(0.22))
                    .frame(width: outer + 10, height: outer + 10)
                    .blur(radius: 8)
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            colors: [color, Color(hex: "#4C4CE0"), Color.white.opacity(0.85), color],
                            center: .center
                        ),
                        lineWidth: 3
                    )
                    .frame(width: outer, height: outer)
                    .rotationEffect(.degrees(angle))
                Circle()
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                    .frame(width: size + 2, height: size + 2)
            }
        }
    }
}

struct CompanionPetView: View {
    var name: String
    var accent: Color
    var style: String

    @State private var bob = false

    var body: some View {
        VStack(spacing: 4) {
            petArt
                .offset(y: bob ? -5 : 4)
            Text(name)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Capsule().fill(.ultraThinMaterial))
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.35).repeatForever(autoreverses: true)) {
                bob = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(name)
    }

    @ViewBuilder
    private var petArt: some View {
        if style == "owl" {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.2))
                    .frame(width: 64, height: 64)
                Image(systemName: "bird.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(accent)
                    .offset(y: 2)
            }
        } else {
            ZStack {
                Capsule()
                    .fill(
                        LinearGradient(colors: [accent, accent.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: 54, height: 44)
                    .shadow(color: accent.opacity(0.35), radius: 6, y: 3)
                HStack(spacing: 10) {
                    Circle().fill(.white).frame(width: 8, height: 8)
                    Circle().fill(.white).frame(width: 8, height: 8)
                }
                .offset(y: -4)
                Capsule()
                    .fill(Color.black.opacity(0.2))
                    .frame(width: 16, height: 5)
                    .offset(y: 8)
            }
        }
    }
}
