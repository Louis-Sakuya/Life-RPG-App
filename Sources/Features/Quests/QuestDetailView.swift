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

            Section(L10n.t("common.schedule")) {
                LabeledContent(L10n.t("quest.scheduled"), value: quest.scheduledDay.description)
                LabeledContent(L10n.t("quest.created_on"), value: quest.createdDay.description)
                if let dueAt = quest.dueAt {
                    LabeledContent(L10n.t("quest.due_at"), value: dueAt.formatted(date: .abbreviated, time: .shortened))
                }
                if let completedAt = quest.completedAt {
                    LabeledContent(L10n.t("quest.completed_at"), value: completedAt.formatted(date: .abbreviated, time: .shortened))
                }
                LabeledContent(L10n.t("quest.estimated"), value: L10n.format("quest.minutes", quest.estimatedMinutes))
            }

            if !quest.tags.isEmpty {
                Section(L10n.t("common.tags")) {
                    HStack {
                        ForEach(quest.tags, id: \.self) { TagChip(text: $0) }
                    }
                }
            }

            Section(L10n.t("common.skills")) {
                let links = quest.skillLinks ?? []
                if links.isEmpty {
                    Text(L10n.t("quest.no_skills"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(links) { link in
                        if let skill = store.skills.first(where: { $0.id == link.skillID }) {
                            HStack {
                                Image(systemName: skill.iconName)
                                    .foregroundStyle(Color(hex: skill.colorHex))
                                Text(skill.localizedName)
                                Spacer()
                                Text(L10n.format("quest.exp_share", Int(link.expShare * 100)))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section(L10n.t("quest.reward_detail")) {
                let reward = store.previewReward(for: quest)
                LabeledContent(L10n.t("quest.base_exp"), value: String(format: "%.0f", reward.baseEXP))
                ForEach(reward.appliedModifiers) { modifier in
                    LabeledContent(modifier.localizedLabel, value: modifier.signedPercentText)
                }
                LabeledContent(L10n.t("quest.final_multiplier"), value: String(format: "×%.2f", reward.multiplier))
                if reward.streakMultiplier > 1 {
                    LabeledContent(L10n.t("quest.streak_bonus"), value: String(format: "×%.2f", reward.streakMultiplier))
                }
                if let fortune = reward.fortuneLabel, reward.fortuneMultiplier > 1 {
                    LabeledContent(fortune, value: String(format: "×%.2f", reward.fortuneMultiplier))
                }
                LabeledContent(L10n.t("quest.total"), value: "\(reward.exp) EXP / \(reward.gold) G")
                    .fontWeight(.semibold)
            }

            Section {
                Button(quest.isCompleted ? L10n.t("quest.uncomplete") : L10n.t("quest.complete")) {
                    store.toggleQuest(quest)
                }
                Button(L10n.t("quest.move_tomorrow")) {
                    store.reschedule(quest, to: store.container.calendar.adding(days: 1, to: store.today))
                }
                Button(L10n.t("quest.delete"), role: .destructive) {
                    store.deleteQuest(quest)
                    dismiss()
                }
            }
        }
        .navigationTitle(L10n.t("quest.detail.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(L10n.t("common.edit")) { isPresentingEditor = true }
            }
        }
        .sheet(isPresented: $isPresentingEditor) {
            QuestEditorView(quest: quest, defaultDay: quest.scheduledDay)
        }
    }
}
