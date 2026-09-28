import SwiftUI

/// 任务中心。四种任务类型在数据层是统一的，这里只是四个视角：
/// 主线 / 支线是对 `Quest` 的过滤，重复是 `QuestTemplate` 列表，挑战是解锁规则的进度。
struct QuestCenterView: View {
    @Environment(GameStore.self) private var store

    private enum Tab: String, CaseIterable, Identifiable {
        case main, side, repeating, challenge
        var id: String { rawValue }
        var title: String {
            switch self {
            case .main: return L10n.t("quest.kind.main")
            case .side: return L10n.t("quest.kind.side")
            case .repeating: return L10n.t("quest.kind.repeating")
            case .challenge: return L10n.t("quest.challenge")
            }
        }
    }

    @State private var tab: Tab = .main
    @State private var publishLaunch: QuestPublishLaunch?
    @State private var isPresentingRepeat = false
    @State private var finishCandidate: QuestTemplate?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker(L10n.t("quest.view"), selection: $tab) {
                    ForEach(Tab.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                Group {
                    switch tab {
                    case .main: questList(kinds: [.main, .repeating], emptyHint: L10n.t("quest.empty.main"))
                    case .side: questList(kinds: [.side], emptyHint: L10n.t("quest.empty.side"))
                    case .repeating: repeatList
                    case .challenge: ChallengeListView()
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(L10n.t("quest.center"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if tab == .repeating {
                            isPresentingRepeat = true
                        } else {
                            publishLaunch = QuestPublishLaunch(
                                boardKind: tab == .side ? .side : .main
                            )
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(tab == .challenge)
                }
            }
            .sheet(item: $publishLaunch) { launch in
                QuestPublishWizardView(initialBoardKind: launch.boardKind)
            }
            .sheet(isPresented: $isPresentingRepeat) {
                RepeatTemplateEditorView()
            }
            .recurringFinishConfirmation(template: $finishCandidate)
        }
    }

    private func questList(kinds: Set<QuestKind>, emptyHint: String) -> some View {
        let grouped = groupedQuests(kinds: kinds)
        return List {
            if grouped.isEmpty {
                EmptyStateView(icon: "tray", title: L10n.t("quest.empty"), message: emptyHint)
                    .listRowBackground(Color.clear)
            }
            ForEach(grouped, id: \.day) { group in
                Section(header: Text(sectionTitle(for: group.day))) {
                    ForEach(group.quests) { quest in
                        NavigationLink {
                            QuestDetailView(quest: quest)
                        } label: {
                            QuestRowView(quest: quest)
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            store.deleteQuest(group.quests[index])
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var repeatList: some View {
        List {
            let templates = store.templates()
            if templates.isEmpty {
                EmptyStateView(
                    icon: "repeat",
                    title: L10n.t("quest.empty.repeat"),
                    message: L10n.t("quest.empty.repeat.message"),
                    actionTitle: L10n.t("quest.empty.repeat.action"),
                    action: { isPresentingRepeat = true }
                )
                .listRowBackground(Color.clear)
            }
            ForEach(templates) { template in
                VStack(alignment: .leading, spacing: 6) {
                    Text(template.title)
                        .font(.body.weight(.medium))
                    HStack(spacing: 6) {
                        StatPill(icon: "repeat", text: template.recurrence.displayText, tint: .teal)
                        StatPill(
                            icon: "hourglass",
                            text: L10n.format("quest.finish.days", durationDays(for: template)),
                            tint: .indigo
                        )
                        if template.completedJourneys > 0 {
                            StatPill(
                                icon: "figure.walk",
                                text: L10n.format("quest.journey.count", template.completedJourneys),
                                tint: .teal
                            )
                        }
                        if template.streakCurrent > 0 {
                            StatPill(icon: "flame.fill", text: "\(template.streakCurrent)", tint: .orange)
                        }
                        if template.isFinished {
                            StatPill(icon: "seal.fill", text: L10n.t("quest.finished"), tint: .orange)
                        } else if !template.isActive {
                            StatPill(icon: "pause.fill", text: L10n.t("common.paused"), tint: .secondary)
                        }
                    }
                }
                .swipeActions {
                    if !template.isFinished {
                        Button(L10n.t("quest.finish")) {
                            finishCandidate = template
                        }
                        .tint(.orange)
                        Button(template.isActive ? L10n.t("common.pause") : L10n.t("common.enable")) {
                            template.isActive.toggle()
                            store.save()
                            store.refresh()
                        }
                    }
                    Button(L10n.t("common.delete"), role: .destructive) {
                        store.deleteTemplate(template)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func groupedQuests(kinds: Set<QuestKind>) -> [(day: GameDay, quests: [Quest])] {
        var days = [store.today]
        days.append(contentsOf: store.upcomingQuests().map(\.scheduledDay))
        days.append(contentsOf: store.overdueQuests.map(\.scheduledDay))
        days.append(contentsOf: store.spanningQuests.map(\.scheduledDay))
        days.append(contentsOf: store.todayCompletedQuests.map(\.scheduledDay))

        let unique = Array(Set(days)).sorted()
        return unique.compactMap { day in
            let quests = store.quests(on: day).filter { kinds.contains($0.kind) }
            return quests.isEmpty ? nil : (day, quests)
        }
    }

    private func sectionTitle(for day: GameDay) -> String {
        let calendar = store.container.calendar
        if day == store.today { return L10n.t("common.today") }
        if day == calendar.adding(days: 1, to: store.today) { return L10n.t("common.tomorrow") }
        if day < store.today { return L10n.format("quest.today_expired", day.shortLabel) }
        return day.shortLabel
    }

    private func durationDays(for template: QuestTemplate) -> Int {
        RecurringFinishEngine.durationDays(
            from: template.startDay,
            to: template.finishedDay ?? store.today,
            calendar: store.container.calendar
        )
    }
}
