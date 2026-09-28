import SwiftUI

/// 首页只展示今天。打开应用看到的是一场正在进行的冒险，
/// 而不是一张无穷的待办清单。任务被收进冒险者工会的告示栏。
struct HomeView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette

    @State private var publishLaunch: QuestPublishLaunch?
    @State private var isPresentingCalendar = false
    @State private var boardFilter: GuildBoardFilter = .all

    private var goldTint: Color { Color(hex: "#D4A017") }

    private enum GuildBoardFilter: String, CaseIterable, Identifiable {
        case all, main, side
        var id: String { rawValue }
        var title: String { L10n.t("home.filter.\(rawValue)") }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppMetrics.sectionSpacing) {
                    PlayerHeaderView()

                    if let fortune = store.todayFortune {
                        luckyDayBanner(fortune)
                    }

                    guildBoard

                    habitSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background { AtmosphereCanvas() }
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
            .overlay(alignment: .bottomTrailing) {
                if let pet = store.equippedPet {
                    CompanionPetView(
                        name: pet.localizedName,
                        accent: Color(hex: pet.accentHex ?? "#7BC96F"),
                        style: pet.styleID
                    )
                    .padding(.trailing, 18)
                    .padding(.bottom, 10)
                }
            }
            .sheet(item: $publishLaunch) { launch in
                QuestPublishWizardView(initialBoardKind: launch.boardKind)
                    .interactiveDismissDisabled(store.isTutorialActive)
            }
            .sheet(isPresented: $isPresentingCalendar) {
                PlanningView()
            }
            .onChange(of: store.tutorialOpenPublish) { _, open in
                guard open else { return }
                store.tutorialOpenPublish = false
                publishLaunch = QuestPublishLaunch()
            }
            .tutorialCoach(host: .home)
            .refreshable {
                store.onForeground()
            }
        }
    }

    // MARK: - 工会任务栏

    private var guildBoard: some View {
        VStack(alignment: .leading, spacing: 14) {
            guildHeader
            guildProgress
            guildCounts
            guildRewards
            guildFilter
            guildQuestPanel
                .animation(.easeInOut(duration: 0.2), value: boardFilter)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    OrnateBorder(
                        cornerRadius: 20,
                        colors: [goldTint, palette.accent.opacity(0.7), goldTint.opacity(0.55)],
                        lineWidth: 1.6
                    )
                )
        )
    }

    private var guildHeader: some View {
        HStack(alignment: .center, spacing: 12) {
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

            Button {
                publishLaunch = QuestPublishLaunch(boardKind: publishKind(for: boardFilter))
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
            .tutorialAnchor(.homePublish)
        }
    }

    private var guildProgress: some View {
        let board = store.guildAllQuests
        let done = board.filter(\.isCompleted).count
        let total = board.count
        let rate = total == 0 ? 0.0 : Double(done) / Double(total)

        return HStack(spacing: 10) {
            ProgressBar(value: rate, gradient: palette.gradient, height: 8)
            Text(L10n.format("home.progress", done, total))
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .fixedSize()
        }
    }

    private var guildCounts: some View {
        HStack(spacing: 8) {
            countTile(
                title: L10n.t("home.count.main"),
                done: store.guildMainQuests.filter(\.isCompleted).count,
                total: store.guildMainQuests.count,
                tint: palette.accent,
                icon: "flag.fill"
            ) {
                boardFilter = .main
            }
            countTile(
                title: L10n.t("home.count.side"),
                done: store.guildSideQuests.filter(\.isCompleted).count,
                total: store.guildSideQuests.count,
                tint: .orange,
                icon: "bolt.fill"
            ) {
                boardFilter = .side
            }
            countTile(
                title: L10n.t("home.count.habits"),
                done: store.todayHabitCompletedCount,
                total: store.todayHabitTotalCount,
                tint: .teal,
                icon: "repeat.circle.fill"
            )
        }
    }

    private var guildRewards: some View {
        HStack(spacing: 10) {
            Image(systemName: "gift.fill")
                .foregroundStyle(goldTint)
            Text(L10n.t("home.reward.today"))
                .font(.subheadline.weight(.medium))
            Spacer(minLength: 8)
            Text("+\(store.todayEXP) EXP")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(palette.accent)
            Text("+\(store.todayGold) G")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(goldTint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(goldTint.opacity(0.10))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.format("home.reward.summary", store.todayEXP, store.todayGold))
    }

    private var guildFilter: some View {
        Picker(L10n.t("home.board_today"), selection: $boardFilter) {
            ForEach(GuildBoardFilter.allCases) { filter in
                Text(filter.title).tag(filter)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var guildQuestPanel: some View {
        switch boardFilter {
        case .all:
            questSubpanel(
                quests: store.guildAllQuests,
                tint: goldTint,
                emptyTitle: L10n.t("home.empty.all.title"),
                emptyMessage: L10n.t("home.empty.all.message"),
                emptyAction: L10n.t("home.empty.all.action"),
                emptyKind: nil
            )
        case .main:
            questSubpanel(
                quests: store.guildMainQuests,
                tint: palette.accent,
                emptyTitle: L10n.t("home.main.empty.title"),
                emptyMessage: L10n.t("home.main.empty.message"),
                emptyAction: L10n.t("home.main.empty.action"),
                emptyKind: .main
            )
        case .side:
            questSubpanel(
                quests: store.guildSideQuests,
                tint: .orange,
                emptyTitle: L10n.t("home.side.empty.title"),
                emptyMessage: L10n.t("home.side.empty.message"),
                emptyAction: L10n.t("home.side.empty.action"),
                emptyKind: .side
            )
        }
    }

    private func questSubpanel(
        quests: [Quest],
        tint: Color,
        emptyTitle: String,
        emptyMessage: String,
        emptyAction: String,
        emptyKind: QuestPublishWizardView.BoardKind?
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
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
                                .fill(kindTint(for: quest))
                                .frame(width: 3)
                                .padding(.vertical, 6)
                            QuestRowView(quest: quest)
                                .padding(.leading, 10)
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        if quest.isOverdue && !quest.isCompleted {
                            Button(L10n.t("quest.move_today")) {
                                store.reschedule(quest, to: store.today)
                            }
                        }
                        Button(L10n.t("common.delete"), role: .destructive) {
                            store.deleteQuest(quest)
                        }
                    }
                }
            }
        }
    }

    private func countTile(
        title: String,
        done: Int,
        total: Int,
        tint: Color,
        icon: String,
        action: (() -> Void)? = nil
    ) -> some View {
        let content = VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(title)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(tint)
            Text(L10n.format("home.count.fraction", done, total))
                .font(.headline.monospacedDigit())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.10))
        )

        return Group {
            if let action {
                Button(action: action) { content }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
            } else {
                content
            }
        }
    }

    private func kindTint(for quest: Quest) -> Color {
        switch quest.kind {
        case .main: return palette.accent
        case .side: return .orange
        case .repeating: return .teal
        }
    }

    private func publishKind(for filter: GuildBoardFilter) -> QuestPublishWizardView.BoardKind? {
        switch filter {
        case .all: return nil
        case .main: return .main
        case .side: return .side
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
}
