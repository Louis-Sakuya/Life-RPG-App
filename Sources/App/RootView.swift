import SwiftUI

struct RootView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        Group {
            if store.needsOnboarding {
                OnboardingView()
            } else {
                mainTabs
            }
        }
        .tint(store.palette.accent)
        .environment(\.palette, store.palette)
        .celebrationOverlay()
        .sheet(isPresented: Binding(
            get: { store.pendingLevelUpChoices.first != nil || store.skillSlotFollowUp != nil },
            set: { _ in }
        )) {
            if let followUp = store.skillSlotFollowUp {
                LevelUpChoiceView(event: followUp, initialStage: .slotFollowUp)
                    .id(followUp.id)
            } else if let event = store.pendingLevelUpChoices.first {
                LevelUpChoiceView(event: event)
                    .id(event.id)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: store.needsOnboarding)
    }

    private var mainTabs: some View {
        TabView {
            HomeView()
                .tabItem { Label(L10n.t("tab.today"), systemImage: "sun.max.fill") }

            QuestCenterView()
                .tabItem { Label(L10n.t("tab.quests"), systemImage: "checklist") }

            GrowthView()
                .tabItem { Label(L10n.t("tab.growth"), systemImage: "chart.line.uptrend.xyaxis") }

            StatisticsView()
                .tabItem { Label(L10n.t("tab.stats"), systemImage: "chart.bar.fill") }

            ProfileView()
                .tabItem { Label(L10n.t("tab.profile"), systemImage: "person.crop.circle.fill") }
        }
    }
}
