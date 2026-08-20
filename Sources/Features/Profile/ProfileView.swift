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

                Section("角色数据") {
                    LabeledContent("累计天数", value: "\(store.player.totalDaysPlayed)")
                    LabeledContent("连续登录", value: "\(store.player.loginStreakCurrent) 天（最长 \(store.player.loginStreakBest) 天）")
                    LabeledContent("完成任务", value: "\(store.player.totalQuestsCompleted)")
                    LabeledContent("主线 / 支线", value: "\(store.player.totalMainQuestsCompleted) / \(store.player.totalSideQuestsCompleted)")
                    LabeledContent("习惯打卡", value: "\(store.player.totalHabitCheckIns) 次")
                    LabeledContent("完美达成", value: "\(store.player.perfectDays) 天")
                    LabeledContent("累计获得", value: "\(store.player.totalEXPEarned) EXP / \(store.player.totalGoldEarned) G")
                }

                Section("成长记录") {
                    NavigationLink {
                        AchievementsView(kind: .achievement)
                    } label: {
                        Label("成就", systemImage: "rosette")
                            .badge(store.unseenUnlockCount())
                    }
                    NavigationLink {
                        TitlesView()
                    } label: {
                        Label("称号", systemImage: "crown.fill")
                    }
                    NavigationLink {
                        ChallengeListView()
                            .navigationTitle("挑战")
                            .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        Label("挑战", systemImage: "trophy.fill")
                    }
                    NavigationLink {
                        LedgerView()
                    } label: {
                        Label("奖励流水", systemImage: "list.bullet.rectangle.portrait")
                    }
                }

                Section {
                    NavigationLink {
                        ShopView()
                    } label: {
                        Label("商店", systemImage: "bag.fill")
                            .badge("\(store.player.gold) G")
                    }
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("设置", systemImage: "gearshape.fill")
                    }
                }
            }
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
