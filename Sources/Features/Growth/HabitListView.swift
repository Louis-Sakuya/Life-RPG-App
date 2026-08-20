import SwiftUI

struct HabitListView: View {
    @Environment(GameStore.self) private var store
    @Binding var isPresentingEditor: Bool

    var body: some View {
        List {
            if store.habits.isEmpty {
                EmptyStateView(
                    icon: "checkmark.circle",
                    title: "还没有习惯",
                    message: "阅读、喝水、运动、写日记……习惯是最稳定的经验来源。",
                    actionTitle: "创建习惯",
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
                        Text("天")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text("最长连续 \(habit.streakBest) 天 · 累计 \(habit.totalCheckIns) 次")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section("最近 30 天") {
                HabitHistoryGrid(habit: habit, days: recentDays(count: 30))
            }

            Section("设置") {
                LabeledContent("每日目标", value: "\(habit.dailyTarget) 次")
                if habit.hasReminder {
                    LabeledContent("提醒时间", value: String(format: "%02d:%02d", habit.reminderHour, habit.reminderMinute))
                } else {
                    LabeledContent("提醒时间", value: "未设置")
                }
            }

            Section {
                Button("今天再打一次卡") {
                    store.checkInHabit(habit)
                }
                Button("撤销今天一次", role: .destructive) {
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
