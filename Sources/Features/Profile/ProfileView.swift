import SwiftUI

struct ProfileView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette

    var body: some View {
        NavigationStack {
            List {
                Section {
                    PlayerHeaderView()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section(L10n.t("profile.character")) {
                    LabeledContent(L10n.t("profile.days_played"), value: "\(store.player.totalDaysPlayed)")
                    LabeledContent(
                        L10n.t("profile.login_streak"),
                        value: L10n.format("profile.login_streak_value", store.player.loginStreakCurrent, store.player.loginStreakBest)
                    )
                    LabeledContent(L10n.t("profile.quests_done"), value: "\(store.player.totalQuestsCompleted)")
                    LabeledContent(
                        L10n.t("profile.main_side"),
                        value: "\(store.player.totalMainQuestsCompleted) / \(store.player.totalSideQuestsCompleted)"
                    )
                    LabeledContent(
                        L10n.t("profile.habit_checkins"),
                        value: L10n.format("profile.habit_checkins_value", store.player.totalHabitCheckIns)
                    )
                    LabeledContent(
                        L10n.t("profile.perfect"),
                        value: L10n.format("profile.perfect_value", store.player.perfectDays)
                    )
                    LabeledContent(
                        L10n.t("profile.lifetime"),
                        value: "\(store.player.totalEXPEarned) EXP / \(store.player.totalGoldEarned) G"
                    )
                }

                Section(L10n.t("profile.core_stats")) {
                    ForEach(CoreStatID.allCases) { stat in
                        LabeledContent(stat.title, value: "Lv\(store.effectiveStatLevel(stat))")
                    }
                    LabeledContent(HiddenStatID.lucky.title, value: "Lv\(store.luckyProgress().level)")
                }

                Section(L10n.t("profile.records")) {
                    NavigationLink {
                        AchievementsView(kind: .achievement)
                    } label: {
                        Label(L10n.t("profile.achievements"), systemImage: "rosette")
                            .badge(store.unseenUnlockCount())
                    }
                    NavigationLink {
                        TitlesView()
                    } label: {
                        Label(L10n.t("profile.titles"), systemImage: "crown.fill")
                    }
                    NavigationLink {
                        ChallengeListView()
                            .navigationTitle(L10n.t("profile.challenges"))
                            .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        Label(L10n.t("profile.challenges"), systemImage: "trophy.fill")
                    }
                    NavigationLink {
                        LedgerView()
                    } label: {
                        Label(L10n.t("profile.ledger"), systemImage: "list.bullet.rectangle.portrait")
                    }
                }

                Section {
                    NavigationLink {
                        ShopView()
                    } label: {
                        Label(L10n.t("profile.shop"), systemImage: "bag.fill")
                            .badge(store.isTestShopSandboxEnabled ? L10n.t("gold.infinite") : "\(store.player.gold) G")
                    }
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label(L10n.t("profile.settings"), systemImage: "gearshape.fill")
                    }
                }
            }
            .navigationTitle(L10n.t("profile.title"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
