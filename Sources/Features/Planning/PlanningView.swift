import SwiftUI

/// 已张贴委托的日历。真正的发布走工会问答向导；这里只负责查看某一天会出现什么。
struct PlanningView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var targetDate = Date()
    @State private var publishLaunch: QuestPublishLaunch?
    @State private var didLoad = false

    private var targetDay: GameDay {
        store.container.calendar.gameDay(fromDisplayDate: targetDate)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker(L10n.t("planning.which_day"), selection: $targetDate) {
                        Text(L10n.t("common.today")).tag(dayDate(offset: 0))
                        Text(L10n.t("common.tomorrow")).tag(dayDate(offset: 1))
                        Text(L10n.t("common.day_after")).tag(dayDate(offset: 2))
                    }
                    .pickerStyle(.segmented)

                    DatePicker(L10n.t("planning.custom_date"), selection: $targetDate, displayedComponents: .date)
                } header: {
                    Text(L10n.t("planning.target_day"))
                } footer: {
                    Text(hintText)
                }

                Section(L10n.t("planning.day_quests")) {
                    let quests = store.quests(on: targetDay)
                    if quests.isEmpty {
                        Text(L10n.t("planning.empty"))
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
                }

                Section {
                    Button {
                        publishLaunch = QuestPublishLaunch()
                    } label: {
                        Label(L10n.t("quest.publish"), systemImage: "scroll.fill")
                    }
                }

                if !repeatPreview.isEmpty {
                    Section {
                        ForEach(repeatPreview, id: \.self) { title in
                            Label(title, systemImage: "repeat")
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text(L10n.t("planning.repeat_preview"))
                    } footer: {
                        Text(L10n.t("planning.repeat_footer"))
                    }
                }
            }
            .navigationTitle(L10n.t("planning.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("common.done")) { dismiss() }
                }
            }
            .sheet(item: $publishLaunch) { launch in
                QuestPublishWizardView(initialBoardKind: launch.boardKind)
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
            return L10n.t("planning.hint.ahead")
        }
        return L10n.t("planning.hint.today")
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
}
