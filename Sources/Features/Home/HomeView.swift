import SwiftUI

/// 首页只展示今天。这是产品的核心约束：打开应用不应该看到一个无穷的待办列表，
/// 而是"今天这一场冒险"。
struct HomeView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette

    @State private var quickAddText = ""
    @State private var isPresentingEditor = false
    @State private var isPresentingPlanning = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppMetrics.sectionSpacing) {
                    PlayerHeaderView()

                    if !store.overdueQuests.isEmpty {
                        overdueSection
                    }

                    mainQuestSection
                    sideQuestSection
                    habitSection
                    todayStatsSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("今日")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingPlanning = true
                    } label: {
                        Label("规划明天", systemImage: "calendar.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingEditor) {
                QuestEditorView(quest: nil, defaultDay: store.today)
            }
            .sheet(isPresented: $isPresentingPlanning) {
                PlanningView()
            }
            .refreshable {
                store.onForeground()
            }
        }
    }

    // MARK: - 分区

    private var overdueSection: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader("延期任务", subtitle: "完成会有 -30% 惩罚，尽快处理或改期")
                ForEach(store.overdueQuests.prefix(5)) { quest in
                    QuestRowView(quest: quest)
                        .contextMenu {
                            Button("挪到今天") {
                                store.reschedule(quest, to: store.today)
                            }
                            Button("删除", role: .destructive) {
                                store.deleteQuest(quest)
                            }
                        }
                }
            }
        }
    }

    private var mainQuestSection: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(
                    "今日主线",
                    subtitle: "昨天规划的任务，奖励加成 +20%",
                    actionTitle: "规划",
                    action: { isPresentingPlanning = true }
                )

                if store.mainQuests.isEmpty {
                    EmptyStateView(
                        icon: "flag.slash",
                        title: "今天还没有主线",
                        message: "主线来自前一天的规划。现在去安排明天，明天的你会感谢今天的你。",
                        actionTitle: "规划明天",
                        action: { isPresentingPlanning = true }
                    )
                } else {
                    ForEach(store.mainQuests) { quest in
                        NavigationLink {
                            QuestDetailView(quest: quest)
                        } label: {
                            QuestRowView(quest: quest)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var sideQuestSection: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader("今日支线", subtitle: "临时冒出来的事，奖励 -50%")

                ForEach(store.sideQuests) { quest in
                    NavigationLink {
                        QuestDetailView(quest: quest)
                    } label: {
                        QuestRowView(quest: quest)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 8) {
                    TextField("快速添加支线…", text: $quickAddText)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.primary.opacity(0.06))
                        )
                        .onSubmit(quickAdd)

                    Button(action: quickAdd) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(palette.accent)
                    }
                    .disabled(quickAddText.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button {
                        isPresentingEditor = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var habitSection: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader("今日习惯", subtitle: "点一下就完成")

                if store.habits.isEmpty {
                    EmptyStateView(
                        icon: "repeat.circle",
                        title: "还没有习惯",
                        message: "习惯是最稳定的经验来源，去成长页添加一个。"
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
                SectionHeader("今日统计")

                HStack(spacing: 12) {
                    statTile(
                        title: "完成率",
                        value: "\(Int(store.todayCompletionRate * 100))%",
                        icon: "chart.pie.fill",
                        tint: palette.accent
                    )
                    statTile(
                        title: "今日EXP",
                        value: "+\(store.todayEXP)",
                        icon: "sparkles",
                        tint: palette.secondary
                    )
                    statTile(
                        title: "今日Gold",
                        value: "+\(store.todayGold)",
                        icon: "dollarsign.circle.fill",
                        tint: Color(hex: "#D4A017")
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

    private func quickAdd() {
        let title = quickAddText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        store.createQuest(title: title, scheduledDay: store.today)
        quickAddText = ""
    }
}
