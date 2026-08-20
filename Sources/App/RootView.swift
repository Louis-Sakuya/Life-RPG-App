import SwiftUI

struct RootView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("今日", systemImage: "sun.max.fill") }

            QuestCenterView()
                .tabItem { Label("任务", systemImage: "checklist") }

            GrowthView()
                .tabItem { Label("成长", systemImage: "chart.line.uptrend.xyaxis") }

            StatisticsView()
                .tabItem { Label("统计", systemImage: "chart.bar.fill") }

            ProfileView()
                .tabItem { Label("我的", systemImage: "person.crop.circle.fill") }
        }
        .tint(store.palette.accent)
        .environment(\.palette, store.palette)
        .celebrationOverlay()
    }
}
