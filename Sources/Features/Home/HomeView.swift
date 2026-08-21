import SwiftUI

/// 首页只展示今天。打开应用看到的是一场正在进行的冒险，
/// 而不是一张无穷的待办清单。任务被收进冒险者工会的告示栏。
struct HomeView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette

    @State private var publishLaunch: QuestPublishLaunch?
    @State private var isPresentingCalendar = false

    private var goldTint: Color { Color(hex: "#D4A017") }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppMetrics.sectionSpacing) {
                    PlayerHeaderView()

                    if let fortune = store.todayFortune {
                        luckyDayBanner(fortune)
                    }

                    if !store.overdueQuests.isEmpty {
                        overdueSection
                    }

                    guildBoard

                    habitSection
                    todayStatsSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(L10n.t("home.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isPresentingCalendar = true
                    } label: {
                        Label(L10n.t("home.calendar"), systemImage: "calendar")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        publishLaunch = QuestPublishLaunch()
                    } label: {
                        Label(L10n.t("home.publish"), systemImage: "scroll.fill")
                    }
                }
            }
            .sheet(item: $publishLaunch) { launch in
                QuestPublishWizardView(initialBoardKind: launch.boardKind)
            }
            .sheet(isPresented: $isPresentingCalendar) {
                PlanningView()
            }
            .refreshable {
                store.onForeground()
            }
        }
    }

    // MARK: - 工会任务栏

    private var guildBoard: some View {
        VStack(alignment: .leading, spacing: 14) {
            guildHeader

            guildLane(
                title: L10n.t("home.main.title"),
                subtitle: L10n.t("home.main.subtitle"),
                icon: "flag.fill",
                tint: palette.accent,
                quests: store.guildMainQuests,
                emptyTitle: L10n.t("home.main.empty.title"),
                emptyMessage: L10n.t("home.main.empty.message"),
                emptyAction: L10n.t("home.main.empty.action"),
                emptyKind: .main
            )

            Divider().opacity(0.35)

            guildLane(
                title: L10n.t("home.side.title"),
                subtitle: L10n.t("home.side.subtitle"),
                icon: "bolt.fill",
                tint: .orange,
                quests: store.guildSideQuests,
                emptyTitle: L10n.t("home.side.empty.title"),
                emptyMessage: L10n.t("home.side.empty.message"),
                emptyAction: L10n.t("home.side.empty.action"),
                emptyKind: .side
            )
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [goldTint.opacity(0.55), palette.accent.opacity(0.35)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.4
                        )
                )
        )
    }

    private var guildHeader: some View {
        let board = store.guildMainQuests + store.guildSideQuests
        let done = board.filter(\.isCompleted).count

        return HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(goldTint.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: "shield.lefthalf.filled")
                    .font(.title3)
                    .foregroundStyle(goldTint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t("home.guild"))
                    .font(.headline)
                Text(L10n.t("home.board_today"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                Button {
                    publishLaunch = QuestPublishLaunch()
                } label: {
                    Label(L10n.t("home.publish"), systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(palette.accent.opacity(0.16))
                        )
                }
                .buttonStyle(.plain)

                if !board.isEmpty {
                    Text(L10n.format("home.progress", done, board.count))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func guildLane(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        quests: [Quest],
        emptyTitle: String,
        emptyMessage: String,
        emptyAction: String,
        emptyKind: QuestPublishWizardView.BoardKind
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if quests.isEmpty {
                VStack(spacing: 8) {
                    Text(emptyTitle)
                        .font(.subheadline.weight(.medium))
                    Text(emptyMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button(emptyAction) {
                        publishLaunch = QuestPublishLaunch(boardKind: emptyKind)
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.top, 2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint.opacity(0.07))
                )
            } else {
                ForEach(quests) { quest in
                    NavigationLink {
                        QuestDetailView(quest: quest)
                    } label: {
                        HStack(spacing: 0) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(tint)
                                .frame(width: 3)
                                .padding(.vertical, 6)
                            QuestRowView(quest: quest)
                                .padding(.leading, 10)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 其他分区

    private func luckyDayBanner(_ fortune: FortuneTier) -> some View {
        let tint = Color(hex: HiddenStatID.lucky.colorHex)
        return HStack(spacing: 12) {
            Image(systemName: "leaf.fill")
                .font(.title3)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.format("home.lucky", fortune.localizedName))
                    .font(.headline)
                Text(
                    fortune.bonusGold > 0
                        ? L10n.format("home.lucky.bonus_gold", fortune.bonusPercentText, fortune.bonusGold)
                        : L10n.format("home.lucky.bonus", fortune.bonusPercentText)
                )
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tint.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(tint.opacity(0.4), lineWidth: 1)
                )
        )
    }

    private var overdueSection: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(L10n.t("home.overdue.title"), subtitle: L10n.t("home.overdue.subtitle"))
                ForEach(store.overdueQuests.prefix(5)) { quest in
                    QuestRowView(quest: quest)
                        .contextMenu {
                            Button(L10n.t("quest.move_today")) {
                                store.reschedule(quest, to: store.today)
                            }
                            Button(L10n.t("common.delete"), role: .destructive) {
                                store.deleteQuest(quest)
                            }
                        }
                }
            }
        }
    }

    private var habitSection: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(L10n.t("home.habits.title"), subtitle: L10n.t("home.habits.subtitle"))

                if store.habits.isEmpty {
                    EmptyStateView(
                        icon: "repeat.circle",
                        title: L10n.t("home.habits.empty.title"),
                        message: L10n.t("home.habits.empty.message")
                    )
                } else {
                    ForEach(store.habits) { habit in
                        HabitCheckRow(habit: habit)
                    }
                }
            }
        }
    }

    private var todayStatsSection: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(L10n.t("home.report"))

                HStack(spacing: 12) {
                    statTile(
                        title: L10n.t("home.completion"),
                        value: "\(Int(store.todayCompletionRate * 100))%",
                        icon: "chart.pie.fill",
                        tint: palette.accent
                    )
                    statTile(
                        title: L10n.t("home.today_exp"),
                        value: "+\(store.todayEXP)",
                        icon: "sparkles",
                        tint: palette.secondary
                    )
                    statTile(
                        title: L10n.t("home.today_gold"),
                        value: "+\(store.todayGold)",
                        icon: "dollarsign.circle.fill",
                        tint: goldTint
                    )
                }

                ProgressBar(value: store.todayCompletionRate, gradient: palette.gradient, height: 8)
            }
        }
    }

    private func statTile(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.10))
        )
    }
}
