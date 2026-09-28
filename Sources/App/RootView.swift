import SwiftUI

struct RootView: View {
    @Environment(GameStore.self) private var store
    @State private var tabItemFrames: [CGRect] = []

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
        .cosmeticFXOverlay()
        .alert(
            L10n.t("fail.alert.title"),
            isPresented: Binding(
                get: { !store.pendingFailedQuests.isEmpty },
                set: { if !$0 { store.dismissFailedQuestAlert() } }
            )
        ) {
            Button(L10n.t("common.ok"), role: .cancel) {
                store.dismissFailedQuestAlert()
            }
        } message: {
            Text(failedAlertMessage)
        }
        .alert(
            L10n.t("alert.streak_shield.title"),
            isPresented: Binding(
                get: { store.player.pendingStreakShieldAlert },
                set: { if !$0 { store.dismissStreakShieldAlert() } }
            )
        ) {
            Button(L10n.t("common.ok"), role: .cancel) {
                store.dismissStreakShieldAlert()
            }
        } message: {
            Text(L10n.t("alert.streak_shield.body"))
        }
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

    private var failedAlertMessage: String {
        let names = store.pendingFailedQuests.map(\.title)
        return L10n.format("fail.alert.message", names.joined(separator: "\n"))
    }

    private var mainTabs: some View {
        ZStack {
            TabView(selection: Binding(
                get: { store.selectedTab },
                set: { store.selectTab($0) }
            )) {
                HomeView()
                    .tabItem { Label(L10n.t("tab.today"), systemImage: "sun.max.fill") }
                    .tag(0)

                GrowthView()
                    .tabItem { Label(L10n.t("tab.growth"), systemImage: "chart.line.uptrend.xyaxis") }
                    .tag(1)

                StatisticsView()
                    .tabItem { Label(L10n.t("tab.stats"), systemImage: "chart.bar.fill") }
                    .tag(2)

                ProfileView()
                    .tabItem { Label(L10n.t("tab.profile"), systemImage: "person.crop.circle.fill") }
                    .tag(3)
            }
        }
        .background {
            TabBarItemFramesReader { tabItemFrames = $0 }
        }
        .tutorialCoach(host: .tabs, tabItemFrames: tabItemFrames)
    }
}
