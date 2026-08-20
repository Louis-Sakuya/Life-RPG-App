import SwiftUI

struct QuestDetailView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    var quest: Quest

    @State private var isPresentingEditor = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(quest.title)
                        .font(.title3.weight(.semibold))
                    if !quest.detail.isEmpty {
                        Text(quest.detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 6) {
                        StatPill(icon: quest.kind.iconName, text: quest.kind.title, tint: palette.accent)
                        StatPill(icon: "star.fill", text: quest.difficulty.title, tint: .orange)
                        StatPill(icon: "arrow.up", text: quest.priority.title, tint: .pink)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("排期") {
                LabeledContent("计划执行", value: quest.scheduledDay.description)
                LabeledContent("创建于", value: quest.createdDay.description)
                if let dueAt = quest.dueAt {
                    LabeledContent("截止时间", value: dueAt.formatted(date: .abbreviated, time: .shortened))
                }
                if let completedAt = quest.completedAt {
                    LabeledContent("完成于", value: completedAt.formatted(date: .abbreviated, time: .shortened))
                }
                LabeledContent("预计时长", value: "\(quest.estimatedMinutes) 分钟")
            }

            if !quest.tags.isEmpty {
                Section("标签") {
                    HStack {
                        ForEach(quest.tags, id: \.self) { TagChip(text: $0) }
                    }
                }
            }

            Section("技能") {
                let links = quest.skillLinks ?? []
                if links.isEmpty {
                    Text("未关联技能")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(links) { link in
                        if let skill = store.skills.first(where: { $0.id == link.skillID }) {
                            HStack {
                                Image(systemName: skill.iconName)
                                    .foregroundStyle(Color(hex: skill.colorHex))
                                Text(skill.name)
                                Spacer()
                                Text("\(Int(link.expShare * 100))% 经验")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section("奖励明细") {
                let reward = store.previewReward(for: quest)
                LabeledContent("基础经验", value: String(format: "%.0f", reward.baseEXP))
                ForEach(reward.appliedModifiers) { modifier in
                    LabeledContent(modifier.label, value: modifier.signedPercentText)
                }
                LabeledContent("最终乘数", value: String(format: "×%.2f", reward.multiplier))
                if reward.streakMultiplier > 1 {
                    LabeledContent("连续加成", value: String(format: "×%.2f", reward.streakMultiplier))
                }
                LabeledContent("合计", value: "\(reward.exp) EXP / \(reward.gold) G")
                    .fontWeight(.semibold)
            }

            Section {
                Button(quest.isCompleted ? "撤销完成" : "标记完成") {
                    store.toggleQuest(quest)
                }
                Button("挪到明天") {
                    store.reschedule(quest, to: store.container.calendar.adding(days: 1, to: store.today))
                }
                Button("删除任务", role: .destructive) {
                    store.deleteQuest(quest)
                    dismiss()
                }
            }
        }
        .navigationTitle("任务详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("编辑") { isPresentingEditor = true }
            }
        }
        .sheet(isPresented: $isPresentingEditor) {
            QuestEditorView(quest: quest, defaultDay: quest.scheduledDay)
        }
    }
}
