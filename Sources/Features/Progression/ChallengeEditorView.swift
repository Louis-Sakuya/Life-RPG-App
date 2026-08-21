import SwiftUI

/// 自定义挑战。用户选的"追踪什么"其实就是在填一条 `UnlockCondition`，
/// 所以自建挑战和内置挑战走的是完全相同的评估路径。
struct ChallengeEditorView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private struct MetricOption: Identifiable, Hashable {
        var key: String
        var title: String
        var unit: String
        var needsSkill = false
        var needsHabit = false
        var id: String { key }
    }

    private var options: [MetricOption] {
        [
            MetricOption(key: MetricKey.totalQuestsCompleted, title: L10n.t("metric.totalQuestsCompleted"), unit: L10n.t("unit.count")),
            MetricOption(key: MetricKey.totalMainQuestsCompleted, title: L10n.t("metric.totalMainQuestsCompleted"), unit: L10n.t("unit.count")),
            MetricOption(key: MetricKey.totalHabitCheckIns, title: L10n.t("metric.totalHabitCheckIns"), unit: L10n.t("unit.times")),
            MetricOption(key: MetricKey.bestLoginStreak, title: L10n.t("metric.bestLoginStreak"), unit: L10n.t("unit.days")),
            MetricOption(key: MetricKey.playerLevel, title: L10n.t("metric.playerLevel"), unit: L10n.t("unit.levels")),
            MetricOption(key: MetricKey.totalStudyMinutes, title: L10n.t("metric.totalStudyMinutes"), unit: L10n.t("unit.minutes")),
            MetricOption(key: MetricKey.totalFocusMinutes, title: L10n.t("metric.totalFocusMinutes"), unit: L10n.t("unit.minutes")),
            MetricOption(key: MetricKey.perfectDays, title: L10n.t("metric.perfectDays"), unit: L10n.t("unit.days")),
            MetricOption(key: MetricKey.skillLevel, title: L10n.t("metric.skillLevel"), unit: L10n.t("unit.levels"), needsSkill: true),
            MetricOption(key: MetricKey.habitStreak, title: L10n.t("metric.habitStreak"), unit: L10n.t("unit.days"), needsHabit: true)
        ]
    }

    @State private var title = ""
    @State private var detail = ""
    @State private var iconName = "trophy.fill"
    @State private var metricKey = MetricKey.totalQuestsCompleted
    @State private var skillName = ""
    @State private var habitName = ""
    @State private var threshold = 100.0
    @State private var rewardEXP = 1000
    @State private var rewardGold = 800

    private var option: MetricOption {
        options.first { $0.key == metricKey } ?? options[0]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.t("common.basic")) {
                    TextField(L10n.t("challenge.name"), text: $title)
                    TextField(L10n.t("quest.detail_placeholder"), text: $detail, axis: .vertical)
                        .lineLimit(1...3)
                }

                Section(L10n.t("common.icon")) {
                    IconPicker(selection: $iconName, tint: .accentColor)
                }

                Section {
                    Picker(L10n.t("challenge.track"), selection: $metricKey) {
                        ForEach(options) { Text($0.title).tag($0.key) }
                    }

                    if option.needsSkill {
                        Picker(L10n.t("common.skills"), selection: $skillName) {
                            Text(L10n.t("challenge.any_skill")).tag("")
                            ForEach(store.skills) { Text($0.localizedName).tag($0.name) }
                        }
                    }
                    if option.needsHabit {
                        Picker(L10n.t("common.habits"), selection: $habitName) {
                            Text(L10n.t("challenge.any_habit")).tag("")
                            ForEach(store.habits) { Text($0.name).tag($0.name) }
                        }
                    }

                    HStack {
                        Text(L10n.t("challenge.target"))
                        Spacer()
                        TextField(L10n.t("challenge.target_placeholder"), value: $threshold, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text(option.unit)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(L10n.t("challenge.condition"))
                } footer: {
                    Text(L10n.t("challenge.condition_footer"))
                }

                Section(L10n.t("common.reward")) {
                    Stepper("EXP \(rewardEXP)", value: $rewardEXP, in: 0...20000, step: 100)
                    Stepper("Gold \(rewardGold)", value: $rewardGold, in: 0...20000, step: 100)
                }
            }
            .navigationTitle(L10n.t("challenge.custom"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("common.save"), action: save)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || threshold <= 0)
                }
            }
        }
    }

    private func save() {
        var param: String?
        if option.needsSkill { param = skillName.isEmpty ? nil : skillName }
        if option.needsHabit { param = habitName.isEmpty ? nil : habitName }

        store.createChallenge(
            title: title,
            detail: detail,
            iconName: iconName,
            metricKey: metricKey,
            metricParam: param,
            threshold: threshold,
            rewardEXP: rewardEXP,
            rewardGold: rewardGold
        )
        dismiss()
    }
}
