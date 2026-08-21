import SwiftUI

struct RepeatTemplateEditorView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var detail = ""
    @State private var difficulty: QuestDifficulty = .normal
    @State private var priority: QuestPriority = .normal
    @State private var estimatedMinutes = 30
    @State private var mode: RecurrenceMode = .daily
    @State private var dailyInterval = 1
    @State private var weekdays: Set<Int> = [2, 4, 6]
    @State private var timesPerWeek = 3
    @State private var monthDays: Set<Int> = [1]
    @State private var startPolicy: RecurrenceStartPolicy = .thisPeriod
    @State private var shares: [UUID: Double] = [:]

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.t("common.basic")) {
                    TextField(L10n.t("quest.title_placeholder"), text: $title)
                    TextField(L10n.t("quest.detail_placeholder"), text: $detail, axis: .vertical)
                        .lineLimit(1...3)
                    Picker(L10n.t("common.difficulty"), selection: $difficulty) {
                        ForEach(QuestDifficulty.allCases) { Text($0.title).tag($0) }
                    }
                    Picker(L10n.t("common.priority"), selection: $priority) {
                        ForEach(QuestPriority.allCases) { Text($0.title).tag($0) }
                    }
                    Stepper(L10n.format("quest.estimated_stepper", estimatedMinutes), value: $estimatedMinutes, in: 5...600, step: 5)
                }

                RecurrenceEditor(
                    mode: $mode,
                    dailyInterval: $dailyInterval,
                    weekdays: $weekdays,
                    timesPerWeek: $timesPerWeek,
                    monthDays: $monthDays,
                    startPolicy: $startPolicy
                )

                Section(L10n.t("quest.skill_share")) {
                    SkillShareEditor(skills: store.skills, shares: $shares, requiresFullAllocation: true)
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
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || (!store.skills.isEmpty && !SkillShareMath.isFullAllocation(shares)))
                }
            }
            .onAppear {
                if shares.isEmpty {
                    shares = SkillShareMath.equalShares(ids: store.skills.map(\.id))
                }
            }
        }
    }

    private func save() {
        store.createTemplate(
            title: title,
            detail: detail,
            difficulty: difficulty,
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
            skillShares: shares.asSkillShares
        )
        dismiss()
    }
}
