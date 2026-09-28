import SwiftUI

struct RepeatTemplateEditorView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var detail = ""
    @State private var estimatedMinutes = 30
    @State private var priority: QuestPriority = .normal
    @State private var mode: RecurrenceMode = .daily
    @State private var dailyInterval = 1
    @State private var weekdays: Set<Int> = [2, 4, 6]
    @State private var timesPerWeek = 3
    @State private var monthDays: Set<Int> = [1]
    @State private var startPolicy: RecurrenceStartPolicy = .thisPeriod
    @State private var maxCompletionsPerDay = 1
    @State private var selectedSkillIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.t("quest.title_placeholder"), text: $title)
                    TextField(L10n.t("quest.detail_placeholder"), text: $detail, axis: .vertical)
                        .lineLimit(1...3)
                    QuestChallengeFields(estimatedMinutes: $estimatedMinutes, priority: $priority)
                } header: {
                    Text(L10n.t("common.basic"))
                } footer: {
                    Text(L10n.t("quest.difficulty.auto_footer"))
                }

                RecurrenceEditor(
                    mode: $mode,
                    dailyInterval: $dailyInterval,
                    weekdays: $weekdays,
                    timesPerWeek: $timesPerWeek,
                    monthDays: $monthDays,
                    startPolicy: $startPolicy,
                    maxCompletionsPerDay: $maxCompletionsPerDay
                )

                Section {
                    SkillPickList(skills: store.skills, selectedIDs: $selectedSkillIDs)
                } header: {
                    Text(L10n.t("wizard.skill_header"))
                } footer: {
                    Text(L10n.t("wizard.skill_footer"))
                }

                Section {
                    ForEach(store.templates()) { template in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(template.title)
                            Text(template.recurrence.displayText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { offsets in
                        let templates = store.templates()
                        for index in offsets {
                            store.deleteTemplate(templates[index])
                        }
                    }
                } header: {
                    Text(L10n.t("quest.repeat.existing"))
                }
            }
            .navigationTitle(L10n.t("quest.repeat.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("common.save"), action: save)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        store.createTemplate(
            title: title,
            detail: detail,
            difficulty: .fromEstimatedMinutes(estimatedMinutes),
            priority: priority,
            estimatedMinutes: estimatedMinutes,
            recurrence: RecurrenceEditor.rule(
                mode: mode,
                dailyInterval: dailyInterval,
                weekdays: weekdays,
                timesPerWeek: timesPerWeek,
                monthDays: monthDays
            ),
            startPolicy: startPolicy,
            skillShares: SkillShareMath.selected(store.skills.map(\.id).filter { selectedSkillIDs.contains($0) }).asSkillShares,
            maxCompletionsPerDay: maxCompletionsPerDay
        )
        dismiss()
    }
}
