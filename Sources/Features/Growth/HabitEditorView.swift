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
                Section("名称") {
                    TextField("例如 阅读、喝水、冥想", text: $name)
                }

                Section("图标与颜色") {
                    IconPicker(selection: $iconName, tint: Color(hex: colorHex))
                    ColorPickerRow(selection: $colorHex)
                }

                Section {
                    Stepper("每天 \(dailyTarget) 次", value: $dailyTarget, in: 1...20)
                } header: {
                    Text("每日目标")
                } footer: {
                    Text("奖励只在达成当日目标的那一次发放，所以把目标拆得更细不会拿到更多经验。")
                }

                Section("提醒") {
                    Toggle("每天提醒", isOn: $hasReminder)
                    if hasReminder {
                        DatePicker("时间", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
                }

                Section("技能经验分配") {
                    SkillShareEditor(skills: store.skills, shares: $shares)
                }
            }
            .navigationTitle("新建习惯")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
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
