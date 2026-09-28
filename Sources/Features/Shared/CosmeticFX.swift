import SwiftUI

enum CosmeticBurstKind {
    /// 任务行上的默认小火花
    case row
    /// 商店「完成火花」的全屏花样
    case complete
    /// 默认升级光粒；商店商品再加密
    case levelUp
}

/// 升级全屏粒子；任务完成的默认反馈在行内，商店特效再叠这一层。
struct CosmeticFXOverlay: ViewModifier {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette

    func body(content: Content) -> some View {
        content
            .overlay {
                if let token = store.completeFXToken {
                    ParticleBurst(
                        kind: .complete,
                        upgraded: true,
                        colors: [palette.accent, Color(hex: "#F0CE6A"), .white, Color(hex: "#E2603B")]
                    )
                    .id(token)
                    .allowsHitTesting(false)
                }
                if let token = store.levelFXToken {
                    ParticleBurst(
                        kind: .levelUp,
                        upgraded: store.hasLevelBurst,
                        colors: [palette.secondary, palette.accent, Color(hex: "#F0CE6A"), .white]
                    )
                    .id(token)
                    .allowsHitTesting(false)
                }
            }
    }
}

struct ParticleBurst: View {
    var kind: CosmeticBurstKind
    var upgraded: Bool = false
    var colors: [Color]

    @State private var progress: CGFloat = 0

    private var count: Int {
        switch kind {
        case .row: return 10
        case .complete: return upgraded ? 28 : 16
        case .levelUp: return upgraded ? 32 : 18
        }
    }

    private var travel: CGFloat {
        switch kind {
        case .row: return 28
        case .complete: return upgraded ? 150 : 88
        case .levelUp: return upgraded ? 168 : 110
        }
    }

    private var duration: Double {
        switch kind {
        case .row: return 0.5
        case .complete: return upgraded ? 0.95 : 0.65
        case .levelUp: return upgraded ? 1.15 : 0.85
        }
    }

    var body: some View {
        ZStack {
            if kind != .row {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [colors.first?.opacity(kind == .levelUp ? 0.38 : 0.22) ?? .white.opacity(0.25), .clear],
                            center: .center,
                            startRadius: 4,
                            endRadius: kind == .levelUp ? 110 : 70
                        )
                    )
                    .scaleEffect(0.35 + progress * 1.7)
                    .opacity(1 - progress)
            }
            ForEach(0..<count, id: \.self) { index in
                Image(systemName: symbol(for: index))
                    .font(.system(size: glyphSize(for: index), weight: .bold))
                    .foregroundStyle(colors[index % colors.count])
                    .offset(particleOffset(index))
                    .scaleEffect(1.2 - progress * 0.75)
                    .opacity(Double(1 - progress))
            }
        }
        .onAppear {
            progress = 0
            withAnimation(.easeOut(duration: duration)) {
                progress = 1
            }
        }
    }

    private func symbol(for index: Int) -> String {
        if upgraded && index.isMultiple(of: 5) { return "circle.fill" }
        if index.isMultiple(of: 4) { return "plus" }
        return index.isMultiple(of: 3) ? "sparkle" : "star.fill"
    }

    private func glyphSize(for index: Int) -> CGFloat {
        let base: CGFloat
        switch kind {
        case .row: base = 7
        case .complete: base = upgraded ? 11 : 9
        case .levelUp: base = upgraded ? 13 : 10
        }
        return base + CGFloat(index % 3)
    }

    private func particleOffset(_ index: Int) -> CGSize {
        let spread = angle(index)
        let distance = travel * progress
        let dx = cos(spread) * distance
        var dy = sin(spread) * distance
        if upgraded && index.isMultiple(of: 5) {
            dy -= progress * 24
        }
        return CGSize(width: dx, height: dy)
    }

    private func angle(_ index: Int) -> CGFloat {
        .pi * 2 * CGFloat(index) / CGFloat(count) + (kind == .levelUp ? 0.18 : 0)
    }
}

/// 任务行上跳出来的实际发放数额。
struct RewardFloater: View {
    var exp: Int
    var gold: Int

    @State private var rise: CGFloat = 8
    @State private var opacity: Double = 0

    var body: some View {
        HStack(spacing: 8) {
            Text(L10n.format("feedback.exp", exp))
                .foregroundStyle(Color(hex: "#5B8DEF"))
            Text(L10n.format("feedback.gold", gold))
                .foregroundStyle(Color(hex: "#D4A017"))
        }
        .font(.caption.weight(.heavy))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        )
        .offset(y: rise)
        .opacity(opacity)
        .onAppear {
            opacity = 1
            withAnimation(.easeOut(duration: 1.15)) {
                rise = -34
                opacity = 0
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension View {
    func cosmeticFXOverlay() -> some View {
        modifier(CosmeticFXOverlay())
    }

    func rewardFeedback(for sourceID: UUID) -> some View {
        modifier(RowRewardFeedback(sourceID: sourceID))
    }
}

private struct RowRewardFeedback: ViewModifier {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    var sourceID: UUID

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .leading) {
                if store.rowSparkSourceID == sourceID {
                    ParticleBurst(
                        kind: .row,
                        colors: [palette.accent, Color(hex: "#F0CE6A"), .white]
                    )
                    .frame(width: 48, height: 48)
                    .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .top) {
                if let popup = store.rewardPopup, popup.sourceID == sourceID {
                    RewardFloater(exp: popup.exp, gold: popup.gold)
                        .id(popup.id)
                        .padding(.top, 2)
                }
            }
    }
}
