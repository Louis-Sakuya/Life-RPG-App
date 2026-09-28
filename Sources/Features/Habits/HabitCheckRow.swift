import SwiftUI

struct HabitCheckRow: View {
    @Environment(GameStore.self) private var store

    var habit: Habit

    var body: some View {
        let progress = store.habitProgress(habit)
        let isDone = progress >= habit.dailyTarget
        let tint = Color(hex: habit.colorHex)

        HStack(spacing: 12) {
            Button {
                if isDone {
                    store.undoHabit(habit)
                } else {
                    store.checkInHabit(habit)
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(tint.opacity(isDone ? 0.9 : 0.14))
                        .frame(width: 38, height: 38)
                    Image(systemName: isDone ? "checkmark" : habit.iconName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isDone ? .white : tint)
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(habit.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(isDone ? Color.secondary : Color.primary)

                HStack(spacing: 6) {
                    if habit.dailyTarget > 1 {
                        Text("\(progress) / \(habit.dailyTarget)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if habit.streakCurrent > 0 {
                        StatPill(icon: "flame.fill", text: "\(habit.streakCurrent)", tint: .orange)
                    }
                }
            }

            Spacer(minLength: 0)

            if habit.dailyTarget > 1 {
                ProgressBar(
                    value: Double(progress) / Double(habit.dailyTarget),
                    gradient: LinearGradient(colors: [tint, tint.opacity(0.6)], startPoint: .leading, endPoint: .trailing),
                    height: 6
                )
                .frame(width: 60)
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .rewardFeedback(for: habit.id)
        .contextMenu {
            if habit.dailyTarget > 1 {
                Button(L10n.t("habit.fill_today")) { store.toggleHabit(habit) }
            }
            Button(L10n.t("habit.undo_once"), role: .destructive) { store.undoHabit(habit) }
        }
    }
}
