import SwiftUI

struct ProfileView: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case overview, honors, shop
        var id: String { rawValue }
        var title: String {
            switch self {
            case .overview: return L10n.t("profile.tab.overview")
            case .honors: return L10n.t("profile.tab.honors")
            case .shop: return L10n.t("profile.tab.shop")
            }
        }
    }

    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    @State private var tab: Tab = .overview

    private var goldTint: Color { Color(hex: "#D4A017") }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker(L10n.t("profile.title"), selection: $tab) {
                    ForEach(Tab.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                Group {
                    switch tab {
                    case .overview: overview
                    case .honors: honors
                    case .shop: ShopView(embedded: true)
                    }
                }
            }
            .background { AtmosphereCanvas() }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if tab == .overview {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            SettingsView()
                        } label: {
                            Image(systemName: "gearshape.fill")
                        }
                        .accessibilityLabel(L10n.t("profile.settings"))
                    }
                }
            }
        }
    }

    private var navigationTitle: String {
        switch tab {
        case .overview: return L10n.t("profile.title")
        case .honors: return L10n.t("profile.tab.honors")
        case .shop: return L10n.t("profile.tab.shop")
        }
    }

    // MARK: - 总览

    private var overview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppMetrics.sectionSpacing) {
                PlayerHeaderView()
                coreAttributes
                lifetimeStats
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    private var coreAttributes: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.t("profile.core_stats"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(CoreStatID.allCases) { stat in
                NavigationLink {
                    StatDetailView(stat: stat)
                } label: {
                    CompactStatRow(stat: stat, progress: store.statProgress(stat), level: store.effectiveStatLevel(stat))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var lifetimeStats: some View {
        let player = store.player
        return VStack(alignment: .leading, spacing: 10) {
            Text(L10n.t("profile.lifetime_stats"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                lifetimeTile(L10n.t("profile.days_played"), formatCount(player.totalDaysPlayed))
                lifetimeTile(L10n.t("profile.login_streak"), formatCount(player.loginStreakCurrent))
                lifetimeTile(L10n.t("profile.best_streak"), formatCount(player.loginStreakBest))
                lifetimeTile(L10n.t("profile.quests_done"), formatCount(player.totalQuestsCompleted))
                lifetimeTile(L10n.t("profile.main_quests"), formatCount(player.totalMainQuestsCompleted))
                lifetimeTile(L10n.t("profile.side_quests"), formatCount(player.totalSideQuestsCompleted))
                lifetimeTile(L10n.t("profile.habit_practice"), formatCount(player.totalHabitCheckIns))
                lifetimeTile(L10n.t("profile.perfect_days"), formatCount(player.perfectDays))
                lifetimeTile(L10n.t("profile.lifetime_exp"), formatCount(player.totalEXPEarned))
                lifetimeTile(L10n.t("profile.lifetime_gold"), formatCount(player.totalGoldEarned))
            }

            NavigationLink {
                FailedQuestHistoryView()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.t("profile.failed_history"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(L10n.format("profile.failed_history_count", store.failedQuestRecords().count))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func lifetimeTile(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.system(.title2, design: .serif).weight(.bold))
                .foregroundStyle(goldTint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func formatCount(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }

    // MARK: - 荣誉

    private var honors: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                honorsBlock(
                    title: L10n.t("profile.achievements"),
                    badge: store.unseenUnlockCount(),
                    isEmpty: achievementPreview.isEmpty,
                    empty: L10n.t("profile.honors.empty.achievements")
                ) {
                    AchievementsView(kind: .achievement)
                } cards: {
                    ForEach(achievementPreview, id: \.rule.id) { entry in
                        UnlockRow(
                            rule: entry.rule,
                            progress: entry.progress,
                            text: entry.text,
                            isUnlocked: entry.isUnlocked
                        )
                    }
                }

                honorsBlock(
                    title: L10n.t("profile.titles"),
                    isEmpty: titlePreview.isEmpty,
                    empty: L10n.t("profile.honors.empty.titles")
                ) {
                    TitlesView()
                } cards: {
                    ForEach(titlePreview, id: \.rule.id) { entry in
                        if entry.isUnlocked {
                            TitleHonorRow(
                                rule: entry.rule,
                                isEquipped: store.player.currentTitleID == entry.rule.id
                            ) {
                                store.equipTitle(entry.rule.id)
                            }
                        } else {
                            UnlockRow(
                                rule: entry.rule,
                                progress: entry.progress,
                                text: entry.text,
                                isUnlocked: false
                            )
                        }
                    }
                }

                honorsBlock(
                    title: L10n.t("profile.challenges"),
                    isEmpty: challengePreview.isEmpty,
                    empty: L10n.t("profile.honors.empty.challenges")
                ) {
                    ChallengeListView()
                        .navigationTitle(L10n.t("profile.challenges"))
                        .navigationBarTitleDisplayMode(.inline)
                } cards: {
                    ForEach(challengePreview, id: \.challenge.id) { entry in
                        ChallengeRow(challenge: entry.challenge, progress: entry.progress, text: entry.text)
                    }
                }

                NavigationLink {
                    LedgerView()
                } label: {
                    HonorSurface {
                        Label(L10n.t("profile.ledger"), systemImage: "list.bullet.rectangle.portrait")
                            .foregroundStyle(.primary)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    private var achievementPreview: [(rule: UnlockRule, progress: Double, text: String?, isUnlocked: Bool)] {
        let entries = store.ruleProgress(kind: .achievement)
        return HonorPreview.mix(
            done: entries.filter(\.isUnlocked),
            near: entries.filter { !$0.isUnlocked }.sorted { $0.progress > $1.progress }
        )
    }

    private var titlePreview: [(rule: UnlockRule, progress: Double, text: String?, isUnlocked: Bool)] {
        let entries = store.ruleProgress(kind: .title)
        let equipped = entries.filter { $0.isUnlocked && $0.rule.id == store.player.currentTitleID }
        let otherDone = entries.filter { $0.isUnlocked && $0.rule.id != store.player.currentTitleID }
        let near = entries.filter { !$0.isUnlocked }.sorted { $0.progress > $1.progress }
        return HonorPreview.mix(done: equipped + otherDone, near: near)
    }

    private var challengePreview: [(challenge: Challenge, progress: Double, text: String?)] {
        let entries = store.challengeProgress()
        return HonorPreview.mix(
            done: entries.filter { $0.challenge.isCompleted },
            near: entries.filter { !$0.challenge.isCompleted }.sorted { $0.progress > $1.progress }
        )
    }

    private func honorsBlock<Destination: View, Cards: View>(
        title: String,
        badge: Int = 0,
        isEmpty: Bool,
        empty: String,
        @ViewBuilder destination: () -> Destination,
        @ViewBuilder cards: () -> Cards
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.title3.weight(.bold))
                if badge > 0 {
                    Text("\(badge)")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(palette.accent))
                        .foregroundStyle(.white)
                }
                Spacer()
                NavigationLink {
                    destination()
                } label: {
                    HStack(spacing: 2) {
                        Text(L10n.t("profile.view_all"))
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.accent)
                }
            }
            if isEmpty {
                Text(empty)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                cards()
            }
        }
    }
}

private enum HonorPreview {
    static let limit = 5

    static func mix<T>(done: [T], near: [T], limit: Int = Self.limit) -> [T] {
        var picked: [T] = []
        picked.append(contentsOf: done.suffix(2))
        picked.append(contentsOf: near.prefix(max(0, limit - picked.count)))
        if picked.count < limit {
            let used = min(2, done.count)
            picked.append(contentsOf: done.dropLast(used).suffix(limit - picked.count))
        }
        return Array(picked.prefix(limit))
    }
}

private struct CompactStatRow: View {
    var stat: CoreStatID
    var progress: LevelProgress
    var level: Int

    var body: some View {
        let tint = Color(hex: stat.colorHex)
        HonorSurface {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(tint.opacity(0.16))
                        .frame(width: 40, height: 40)
                    Image(systemName: stat.iconName)
                        .foregroundStyle(tint)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(stat.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("Lv.\(level)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(tint)
                    }
                    ProgressBar(
                        value: progress.progress,
                        gradient: LinearGradient(colors: [tint, tint.opacity(0.55)], startPoint: .leading, endPoint: .trailing),
                        height: 7
                    )
                }
            }
        }
    }
}
