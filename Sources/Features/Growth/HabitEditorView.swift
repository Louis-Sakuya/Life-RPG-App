import SwiftUI

struct HabitEditorView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var iconName = "checkmark.circle.fill"
    @State private var colorHex = "#2FA36B"
    @State private var dailyTarget = 1
    @State private var hasReminder = false
    @State private var reminderTime = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var shares: [UUID: Double] = [:]

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.t("common.name")) {
                    TextField(L10n.t("habit.name_placeholder"), text: $name)
                }

                Section(L10n.t("habit.icon_color")) {
                    IconPicker(selection: $iconName, tint: Color(hex: colorHex))
                    ColorPickerRow(selection: $colorHex)
                }

                Section {
                    Stepper(L10n.format("habit.times_per_day", dailyTarget), value: $dailyTarget, in: 1...20)
                } header: {
                    Text(L10n.t("habit.daily_target"))
                } footer: {
                    Text(L10n.t("habit.target_footer"))
                }

                Section(L10n.t("habit.reminder")) {
                    Toggle(L10n.t("habit.remind_daily"), isOn: $hasReminder)
                    if hasReminder {
                        DatePicker(L10n.t("habit.time"), selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
                }

                Section(L10n.t("quest.skill_share")) {
                    SkillShareEditor(skills: store.skills, shares: $shares)
                }
            }
            .navigationTitle(L10n.t("habit.new"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("common.save"), action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        store.createHabit(
            name: name,
            iconName: iconName,
            colorHex: colorHex,
            dailyTarget: dailyTarget,
            reminderHour: hasReminder ? (components.hour ?? 21) : -1,
            reminderMinute: components.minute ?? 0,
            skillShares: shares.asSkillShares
        )
        store.syncNotifications()
        dismiss()
    }
}
