import SwiftUI
import UIKit

struct TutorialAnchorKey: PreferenceKey {
    static var defaultValue: [TutorialAnchorID: CGRect] = [:]

    static func reduce(value: inout [TutorialAnchorID: CGRect], nextValue: () -> [TutorialAnchorID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

extension View {
    func tutorialAnchor(_ id: TutorialAnchorID) -> some View {
        background {
            GeometryReader { geo in
                Color.clear.preference(key: TutorialAnchorKey.self, value: [id: geo.frame(in: .global)])
            }
        }
    }

    func tutorialCoach(host: TutorialHost, tabItemFrames: [CGRect] = []) -> some View {
        modifier(TutorialCoachModifier(host: host, tabItemFrames: tabItemFrames))
    }
}

private struct TutorialCoachModifier: ViewModifier {
    @Environment(GameStore.self) private var store
    var host: TutorialHost
    var tabItemFrames: [CGRect]

    @State private var anchors: [TutorialAnchorID: CGRect] = [:]

    func body(content: Content) -> some View {
        content
            .onPreferenceChange(TutorialAnchorKey.self) { anchors = $0 }
            .overlay {
                if store.isTutorialActive, store.tutorialStep?.host == host {
                    TutorialCoachOverlay(anchors: anchors, tabItemFrames: tabItemFrames)
                }
            }
    }
}

struct TabBarItemFramesReader: UIViewRepresentable {
    var onChange: ([CGRect]) -> Void

    func makeUIView(context: Context) -> TabBarProbeView {
        let view = TabBarProbeView()
        view.onChange = onChange
        return view
    }

    func updateUIView(_ uiView: TabBarProbeView, context: Context) {
        uiView.onChange = onChange
        uiView.report()
    }
}

final class TabBarProbeView: UIView {
    var onChange: ([CGRect]) -> Void = { _ in }
    private var lastFrames: [CGRect] = []

    override func didMoveToWindow() {
        super.didMoveToWindow()
        report()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        report()
    }

    func report() {
        let frames = TabBarGeometry.itemFrames()
        guard frames != lastFrames else { return }
        lastFrames = frames
        DispatchQueue.main.async { [weak self] in
            self?.onChange(frames)
        }
    }
}

enum TabBarGeometry {
    static func itemFrames() -> [CGRect] {
        guard let tabBar = findTabBar() else { return [] }
        let buttons = tabBarButtons(in: tabBar).sorted { $0.frame.minX < $1.frame.minX }
        if buttons.count >= 2 {
            return buttons.map { tabBar.convert($0.frame, to: nil) }
        }
        let count: CGFloat = 4
        let width = tabBar.bounds.width / count
        return (0..<4).map { index in
            tabBar.convert(
                CGRect(x: CGFloat(index) * width, y: 0, width: width, height: tabBar.bounds.height),
                to: nil
            )
        }
    }

    private static func tabBarButtons(in view: UIView) -> [UIView] {
        let name = String(describing: type(of: view))
        if name.contains("TabBarButton") {
            return [view]
        }
        return view.subviews.flatMap { tabBarButtons(in: $0) }
    }

    private static func findTabBar() -> UITabBar? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .filter { !$0.isHidden }
        for window in windows {
            if let bar = findTabBar(in: window) { return bar }
        }
        return nil
    }

    private static func findTabBar(in view: UIView) -> UITabBar? {
        if let bar = view as? UITabBar { return bar }
        for subview in view.subviews {
            if let bar = findTabBar(in: subview) { return bar }
        }
        return nil
    }
}

struct TutorialCoachOverlay: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette

    var anchors: [TutorialAnchorID: CGRect]
    var tabItemFrames: [CGRect] = []

    private var goldTint: Color { Color(hex: "#D4A017") }

    var body: some View {
        if let step = store.tutorialStep {
            GeometryReader { geo in
                let hole = localHole(for: step, in: geo)
                ZStack(alignment: .topLeading) {
                    if !step.allowsFormEntry {
                        spotlight(hole: hole, canvas: geo.size)
                    }

                    if step.highlightIsButton, let hole {
                        Button {
                            store.performTutorialHighlightAction()
                        } label: {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(goldTint, lineWidth: 3)
                                .shadow(color: goldTint.opacity(0.55), radius: 8)
                        }
                        .frame(width: hole.width, height: hole.height)
                        .position(x: hole.midX, y: hole.midY)
                    }

                    tooltip(step, hole: hole, canvas: geo.size)
                        .allowsHitTesting(step.showsPrimary)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(!step.allowsFormEntry)
        }
    }

    private func localHole(for step: TutorialStep, in geo: GeometryProxy) -> CGRect? {
        if step == .goGrowth {
            return tabBarHole(index: 1, in: geo)
        }
        let origin = geo.frame(in: .global).origin
        guard let id = step.anchor, let global = anchors[id] else { return nil }
        return CGRect(
            x: global.minX - origin.x - 8,
            y: global.minY - origin.y - 8,
            width: global.width + 16,
            height: global.height + 16
        )
    }

    private func tabBarHole(index: Int, in geo: GeometryProxy) -> CGRect? {
        let origin = geo.frame(in: .global).origin
        if tabItemFrames.indices.contains(index) {
            let global = tabItemFrames[index]
            return CGRect(
                x: global.minX - origin.x - 6,
                y: global.minY - origin.y - 4,
                width: global.width + 12,
                height: global.height + 8
            )
        }
        let width = geo.size.width / 4
        let height: CGFloat = 49
        let bottomInset = max(geo.safeAreaInsets.bottom, 34)
        return CGRect(
            x: width * CGFloat(index),
            y: geo.size.height - height - bottomInset,
            width: width,
            height: height
        )
    }

    private func spotlight(hole: CGRect?, canvas: CGSize) -> some View {
        Canvas { context, size in
            var path = Path(CGRect(origin: .zero, size: size))
            if let hole {
                path.addRoundedRect(
                    in: hole,
                    cornerRadii: RectangleCornerRadii(topLeading: 16, bottomLeading: 16, bottomTrailing: 16, topTrailing: 16)
                )
            }
            context.fill(path, with: .color(.black.opacity(0.66)), style: FillStyle(eoFill: true))
        }
        .frame(width: canvas.width, height: canvas.height)
        .contentShape(Rectangle())
        .onTapGesture {}
    }

    @ViewBuilder
    private func tooltip(_ step: TutorialStep, hole: CGRect?, canvas: CGSize) -> some View {
        let card = tooltipCard(step)
            .frame(maxWidth: min(340, canvas.width - 32))

        if step.showsPrimary {
            card
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if step == .goGrowth {
            VStack {
                Spacer(minLength: 0)
                card
                Spacer().frame(height: max(96, (hole.map { canvas.height - $0.minY } ?? 96) + 16))
            }
            .frame(width: canvas.width, height: canvas.height)
        } else if step.allowsFormEntry || hole == nil {
            VStack {
                Spacer(minLength: 0)
                card.padding(.bottom, 28)
            }
            .frame(width: canvas.width, height: canvas.height)
        } else if let hole {
            let placeBelow = hole.midY < canvas.height * 0.48
            VStack(spacing: 14) {
                if placeBelow {
                    Color.clear.frame(height: max(0, hole.maxY))
                    card
                    Spacer(minLength: 8)
                } else {
                    Spacer(minLength: 8)
                    card
                    Color.clear.frame(height: max(0, canvas.height - hole.minY))
                }
            }
            .frame(width: canvas.width, height: canvas.height)
        }
    }

    private func tooltipCard(_ step: TutorialStep) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(step.title)
                .font(.headline.weight(.bold))
            Text(step.message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if step.showsPrimary {
                Button(step.primaryTitle) {
                    store.performTutorialPrimary()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.22), radius: 14, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(goldTint.opacity(0.45), lineWidth: 1)
        )
    }
}
