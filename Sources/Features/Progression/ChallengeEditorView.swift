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

    private static let options: [MetricOption] = [
        MetricOption(key: MetricKey.totalQuestsCompleted, title: "累计完成任务", unit: "个"),
        MetricOption(key: MetricKey.totalMainQuestsCompleted, title: "累计完成主线", unit: "个"),
        MetricOption(key: MetricKey.totalHabitCheckIns, title: "累计打卡", unit: "次"),
        MetricOption(key: MetricKey.bestLoginStreak, title: "最长连续登录", unit: "天"),
        MetricOption(key: MetricKey.playerLevel, title: "玩家等级", unit: "级"),
        MetricOption(key: MetricKey.totalStudyMinutes, title: "累计学习时长", unit: "分钟"),
        MetricOption(key: MetricKey.totalFocusMinutes, title: "累计专注时长", unit: "分钟"),
        MetricOption(key: MetricKey.perfectDays, title: "完美达成天数", unit: "天"),
        MetricOption(key: MetricKey.skillLevel, title: "指定技能等级", unit: "级", needsSkill: true),
        MetricOption(key: MetricKey.habitStreak, title: "指定习惯连续", unit: "天", needsHabit: true)
    ]

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
        Self.options.first { $0.key == metricKey } ?? Self.options[0]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本") {
                    TextField("挑战名称", text: $title)
                    TextField("描述（可选）", text: $detail, axis: .vertical)
                        .lineLimit(1...3)
                }

                Section("图标") {
                    IconPicker(selection: $iconName, tint: .accentColor)
                }

                Section {
                    Picker("追踪什么", selection: $metricKey) {
                        ForEach(Self.options) { Text($0.title).tag($0.key) }
                    }

                    if option.needsSkill {
                        Picker("技能", selection: $skillName) {
                            Text("任意技能").tag("")
                            ForEach(store.skills) { Text($0.name).tag($0.name) }
                        }
                    }
                    if option.needsHabit {
                        Picker("习惯", selection: $habitName) {
                            Text("任意习惯").tag("")
                            ForEach(store.habits) { Text($0.name).tag($0.name) }
                        }
                    }

                    HStack {
                        Text("目标值")
                        Spacer()
                        TextField("目标", value: $threshold, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text(option.unit)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("达成条件")
                } footer: {
                    Text("挑战会持续对照你的真实数据自动判定，达成时自动结算奖励。")
                }

                Section("奖励") {
                    Stepper("EXP \(rewardEXP)", value: $rewardEXP, in: 0...20000, step: 100)
                    Stepper("Gold \(rewardGold)", value: $rewardGold, in: 0...20000, step: 100)
                }
            }
            .navigationTitle("自定义挑战")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
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
