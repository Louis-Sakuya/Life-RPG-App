import SwiftUI

struct QuestRowView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette

    var quest: Quest
    var showsRewardPreview: Bool = true

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                store.toggleQuest(quest)
            } label: {
                Image(systemName: quest.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(quest.isCompleted ? palette.accent : Color.secondary.opacity(0.5))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                Text(quest.title)
                    .font(.body.weight(.medium))
                    .strikethrough(quest.isCompleted, color: .secondary)
                    .foregroundStyle(quest.isCompleted ? Color.secondary : Color.primary)

                if !quest.detail.isEmpty {
                    Text(quest.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 6) {
                    StatPill(icon: quest.kind.iconName, text: quest.kind.title, tint: kindTint)
                    if quest.isOverdue && !quest.isCompleted {
                        StatPill(icon: "clock.badge.exclamationmark", text: L10n.t("quest.status.overdue"), tint: .red)
                    }
                    if let weekly = weeklyRemainingText {
                        StatPill(icon: "repeat", text: weekly, tint: .teal)
                    }
                    if let daily = dailyCapText {
                        StatPill(icon: "sun.max", text: daily, tint: .orange)
                    }
                    if let remaining = remainingText {
                        StatPill(icon: "timer", text: remaining, tint: .secondary)
                    }
                }

                if !quest.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(quest.tags.prefix(3), id: \.self) { TagChip(text: $0) }
                    }
                }

                if showsRewardPreview {
                    rewardLine
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .rewardFeedback(for: quest.id)
    }

    /// 预估收益直接展示在卡片上。玩家在决定"先做哪件事"之前就能看到差异，
    /// 这是奖励系统真正产生引导力的前提。
    private var rewardLine: some View {
        let reward = store.previewReward(for: quest)
        return HStack(spacing: 8) {
            Text("+\(reward.exp) EXP")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.accent)
            Text("+\(reward.gold) G")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(hex: "#D4A017"))
            if let highlight = reward.appliedModifiers.max(by: { abs($0.value) < abs($1.value) }) {
                Text("\(highlight.localizedLabel) \(highlight.signedPercentText)")
                    .font(.caption2)
                    .foregroundStyle(highlight.value >= 0 ? Color.green : Color.red)
            }
            if let fortune = reward.fortuneLabel, reward.fortuneMultiplier > 1 {
                Text(fortune)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color(hex: HiddenStatID.lucky.colorHex))
            }
        }
    }

    private var kindTint: Color {
        switch quest.kind {
        case .main: return palette.accent
        case .side: return .orange
        case .repeating: return .teal
        }
    }

    private var weeklyRemainingText: String? {
        guard let progress = store.repeatingProgress(for: quest) else { return nil }
        return L10n.format("quest.remaining.week", progress.remaining)
    }

    private var dailyCapText: String? {
        guard store.repeatingProgress(for: quest) != nil else { return nil }
        if store.isTodayPaused() {
            return L10n.t("quest.paused.today")
        }
        if let progress = store.repeatingProgress(for: quest), progress.dailyLeft <= 0, !quest.isCompleted {
            return L10n.t("quest.daily_cap.reached")
        }
        return nil
    }

    private var remainingText: String? {
        guard let dueAt = quest.dueAt, !quest.isCompleted else { return nil }
        let interval = dueAt.timeIntervalSinceNow
        guard interval > 0 else { return L10n.t("quest.status.overtime") }
        let hours = Int(interval) / 3600
        if hours >= 24 { return L10n.format("quest.remaining.days", hours / 24) }
        if hours >= 1 { return L10n.format("quest.remaining.hours", hours) }
        return L10n.format("quest.remaining.minutes", max(1, Int(interval) / 60))
    }
}
