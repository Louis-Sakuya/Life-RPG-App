import SwiftUI

struct HabitListView: View {
    @Environment(GameStore.self) private var store
    @Binding var isPresentingEditor: Bool

    var body: some View {
        List {
            if store.habits.isEmpty {
                EmptyStateView(
                    icon: "checkmark.circle",
                    title: L10n.t("habit.empty.title"),
                    message: L10n.t("habit.empty.message"),
                    actionTitle: L10n.t("habit.empty.action"),
                    action: { isPresentingEditor = true }
                )
                .listRowBackground(Color.clear)
            }

            ForEach(store.habits) { habit in
                NavigationLink {
                    HabitDetailView(habit: habit)
                } label: {
                    HabitCheckRow(habit: habit)
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    store.deleteHabit(store.habits[index])
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct HabitDetailView: View {
    @Environment(GameStore.self) private var store

    var habit: Habit

    var body: some View {
        let tint = Color(hex: habit.colorHex)

        List {
            Section {
                VStack(spacing: 10) {
                    Image(systemName: habit.iconName)
                        .font(.system(size: 38))
                        .foregroundStyle(tint)
                    Text(habit.name)
                        .font(.title3.weight(.semibold))
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        Text("\(habit.streakCurrent)")
                            .font(.largeTitle.weight(.bold))
                        Text(L10n.t("habit.days"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text(L10n.format("habit.best", habit.streakBest, habit.totalCheckIns))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section(L10n.t("habit.last_30")) {
                HabitHistoryGrid(habit: habit, days: recentDays(count: 30))
            }

            Section(L10n.t("common.settings")) {
                LabeledContent(L10n.t("habit.daily_target"), value: L10n.format("habit.times_value", habit.dailyTarget))
                if habit.hasReminder {
                    LabeledContent(
                        L10n.t("settings.reminder_time"),
                        value: String(format: "%02d:%02d", habit.reminderHour, habit.reminderMinute)
                    )
                } else {
                    LabeledContent(L10n.t("settings.reminder_time"), value: L10n.t("habit.reminder_unset"))
                }
            }

            Section {
                Button(L10n.t("habit.check_again")) {
                    store.checkInHabit(habit)
                }
                Button(L10n.t("habit.undo_today"), role: .destructive) {
                    store.undoHabit(habit)
                }
            }
        }
        .navigationTitle(habit.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func recentDays(count: Int) -> [GameDay] {
        let calendar = store.container.calendar
        return (0..<count).reversed().map { calendar.adding(days: -$0, to: store.today) }
    }
}

struct HabitHistoryGrid: View {
    @Environment(GameStore.self) private var store

    var habit: Habit
    var days: [GameDay]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 10)

    var body: some View {
        let tint = Color(hex: habit.colorHex)
        let logs = Dictionary(
            uniqueKeysWithValues: (habit.logs ?? []).map { ($0.dayValue, $0.count) }
        )

        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(days, id: \.value) { day in
                let count = logs[day.value] ?? 0
                let ratio = habit.dailyTarget > 0 ? Double(count) / Double(habit.dailyTarget) : 0
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(tint.opacity(ratio <= 0 ? 0.08 : 0.25 + 0.65 * min(1, ratio)))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(alignment: .center) {
                        if day == store.today {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(tint, lineWidth: 1.2)
                        }
                    }
            }
        }
        .padding(.vertical, 4)
    }
}
