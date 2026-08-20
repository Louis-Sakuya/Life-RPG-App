import SwiftUI

/// 任务中心。四种任务类型在数据层是统一的，这里只是四个视角：
/// 主线 / 支线是对 `Quest` 的过滤，重复是 `QuestTemplate` 列表，挑战是解锁规则的进度。
struct QuestCenterView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette

    private enum Tab: String, CaseIterable, Identifiable {
        case main, side, repeating, challenge
        var id: String { rawValue }
        var title: String {
            switch self {
            case .main: return "主线"
            case .side: return "支线"
            case .repeating: return "重复"
            case .challenge: return "挑战"
            }
        }
    }

    @State private var tab: Tab = .main
    @State private var isPresentingEditor = false
    @State private var isPresentingRepeat = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("视角", selection: $tab) {
                    ForEach(Tab.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                Group {
                    switch tab {
                    case .main: questList(kinds: [.main, .repeating], emptyHint: "主线来自提前规划")
                    case .side: questList(kinds: [.side], emptyHint: "支线是当天临时添加的任务")
                    case .repeating: repeatList
                    case .challenge: ChallengeListView()
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("任务中心")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if tab == .repeating {
                            isPresentingRepeat = true
                        } else {
                            isPresentingEditor = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(tab == .challenge)
                }
            }
            .sheet(isPresented: $isPresentingEditor) {
                QuestEditorView(
                    quest: nil,
                    defaultDay: tab == .side ? store.today : store.container.calendar.adding(days: 1, to: store.today)
                )
            }
            .sheet(isPresented: $isPresentingRepeat) {
                RepeatTemplateEditorView()
            }
        }
    }

    private func questList(kinds: Set<QuestKind>, emptyHint: String) -> some View {
        let grouped = groupedQuests(kinds: kinds)
        return List {
            if grouped.isEmpty {
                EmptyStateView(icon: "tray", title: "还没有任务", message: emptyHint)
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
                    title: "还没有重复任务",
                    message: "每天阅读、每周健身三次、每月总结，都可以在这里设置。",
                    actionTitle: "创建周期任务",
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
                        DifficultyStars(value: template.difficultyRaw, tint: .orange)
                        if template.streakCurrent > 0 {
                            StatPill(icon: "flame.fill", text: "\(template.streakCurrent)", tint: .orange)
                        }
                        if !template.isActive {
                            StatPill(icon: "pause.fill", text: "已暂停", tint: .secondary)
                        }
                    }
                }
                .swipeActions {
                    Button(template.isActive ? "暂停" : "启用") {
                        template.isActive.toggle()
                        store.save()
                        store.refresh()
                    }
                    Button("删除", role: .destructive) {
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

        let unique = Array(Set(days)).sorted()
        return unique.compactMap { day in
            let quests = store.quests(on: day).filter { kinds.contains($0.kind) }
            return quests.isEmpty ? nil : (day, quests)
        }
    }

    private func sectionTitle(for day: GameDay) -> String {
        let calendar = store.container.calendar
        if day == store.today { return "今天" }
        if day == calendar.adding(days: 1, to: store.today) { return "明天" }
        if day < store.today { return "\(day.shortLabel)（已过期）" }
        return day.shortLabel
    }
}
