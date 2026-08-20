import SwiftUI
import SwiftData

@main
struct LifeRPGApp: App {
    @State private var store: GameStore
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // App 的 init 在语言层面不是主线程隔离的，但 SwiftUI 保证它在主线程执行。
        // 容器与 Store 都是 @MainActor，因此这里显式声明这一事实。
        let store = MainActor.assumeIsolated {
            GameStore(container: AppContainer())
        }
        _store = State(initialValue: store)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(\.palette, store.palette)
                .modelContainer(store.container.modelContainer)
                .preferredColorScheme(colorScheme)
                .task {
                    store.bootstrap()
                }
                .onChange(of: scenePhase) { _, phase in
                    // 跨过午夜的场景只有在回到前台时才能被发现，
                    // 因此每日结算必须挂在这里而不是只在启动时跑一次
                    if phase == .active {
                        store.onForeground()
                    } else {
                        store.save()
                    }
                }
        }
    }

    private var colorScheme: ColorScheme? {
        switch store.settings.appearance {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
