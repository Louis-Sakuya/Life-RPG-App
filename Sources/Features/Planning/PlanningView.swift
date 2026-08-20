import SwiftUI

/// 未来规划。整个产品的核心页面：在这里安排的任务，到了那天会自动成为主线并带 +20% 加成。
///
/// 这个自动化不依赖任何定时任务，而是由 `Quest.kind` 的派生规则天然实现的
/// （计划日晚于创建日 → 主线）。
struct PlanningView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    @State private var targetDate = Date()
    @State private var quickAddText = ""
    @State private var isPresentingEditor = false
    @State private var isPresentingRepeat = false
    @State private var didLoad = false

    private var targetDay: GameDay {
        store.container.calendar.gameDay(for: targetDate)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("规划哪天", selection: $targetDate) {
                        Text("今天").tag(dayDate(offset: 0))
                        Text("明天").tag(dayDate(offset: 1))
                        Text("后天").tag(dayDate(offset: 2))
                    }
                    .pickerStyle(.segmented)

                    DatePicker("自定义日期", selection: $targetDate, displayedComponents: .date)
                } header: {
                    Text("目标日")
                } footer: {
                    Text(hintText)
                }

                Section("当天安排") {
                    let quests = store.quests(on: targetDay)
                    if quests.isEmpty {
                        Text("这一天还是空的")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(quests) { quest in
                            QuestRowView(quest: quest, showsRewardPreview: true)
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                store.deleteQuest(quests[index])
                            }
                        }
                    }

                    HStack {
                        TextField("添加任务…", text: $quickAddText)
                            .onSubmit(quickAdd)
                        Button(action: quickAdd) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(palette.accent)
                        }
                        .disabled(quickAddText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                Section {
                    Button {
                        isPresentingEditor = true
                    } label: {
                        Label("详细添加（难度、技能、截止时间）", systemImage: "slider.horizontal.3")
                    }
                    Button {
                        isPresentingRepeat = true
                    } label: {
                        Label("添加周期任务", systemImage: "repeat")
                    }
                }

                if !repeatPreview.isEmpty {
                    Section {
                        ForEach(repeatPreview, id: \.self) { title in
                            Label(title, systemImage: "repeat")
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("当天会自动生成的重复任务")
                    } footer: {
                        Text("重复任务在当天开始时自动生成，视同提前规划。")
                    }
                }
            }
            .navigationTitle("规划")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(isPresented: $isPresentingEditor) {
                QuestEditorView(quest: nil, defaultDay: targetDay)
            }
            .sheet(isPresented: $isPresentingRepeat) {
                RepeatTemplateEditorView()
            }
            .onAppear {
                guard !didLoad else { return }
                didLoad = true
                targetDate = dayDate(offset: 1)
            }
        }
    }

    private var hintText: String {
        if targetDay > store.today {
            return "安排在未来的任务，到了那天会自动变成主线，并获得 +20% 提前规划加成。"
        }
        return "安排在今天的任务是支线，奖励会打五折。规划的价值就在这个差距里。"
    }

    /// 只做展示不落库。提前把重复任务写进数据库会导致模板改动后留下孤儿实例。
    private var repeatPreview: [String] {
        let calendar = store.container.calendar
        return store.templates()
            .filter { $0.isActive }
            .filter { template in
                let anchor = ScheduleEngine.effectiveStartDay(
                    rule: template.recurrence,
                    startDay: template.startDay,
                    policy: template.startPolicy,
                    calendar: calendar
                )
                return ScheduleEngine.occurs(
                    rule: template.recurrence,
                    on: targetDay,
                    anchor: anchor,
                    calendar: calendar
                )
            }
            .map(\.title)
    }

    private func dayDate(offset: Int) -> Date {
        let calendar = store.container.calendar
        return calendar.displayDate(of: calendar.adding(days: offset, to: store.today))
    }

    private func quickAdd() {
        let title = quickAddText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        store.createQuest(title: title, scheduledDay: targetDay)
        quickAddText = ""
    }
}
