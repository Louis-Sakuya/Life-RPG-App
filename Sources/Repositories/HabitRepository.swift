import Foundation
import SwiftData

struct HabitRepository {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func allHabits(includeArchived: Bool = false) -> [Habit] {
        let descriptor = FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)])
        let habits = (try? context.fetch(descriptor)) ?? []
        return includeArchived ? habits : habits.filter { !$0.isArchived }
    }

    func habit(id: UUID) -> Habit? {
        let descriptor = FetchDescriptor<Habit>(predicate: #Predicate { $0.id == id })
        return (try? context.fetch(descriptor))?.first
    }

    func log(for habit: Habit, on day: GameDay) -> HabitLog? {
        (habit.logs ?? []).first { $0.dayValue == day.value }
    }

    @discardableResult
    func ensureLog(for habit: Habit, on day: GameDay) -> HabitLog {
        if let existing = log(for: habit, on: day) { return existing }
        let created = HabitLog(day: day)
        created.habit = habit
        context.insert(created)
        if habit.logs == nil { habit.logs = [] }
        habit.logs?.append(created)
        return created
    }

    func logs(for habit: Habit, in range: ClosedRange<GameDay>) -> [HabitLog] {
        (habit.logs ?? [])
            .filter { $0.dayValue >= range.lowerBound.value && $0.dayValue <= range.upperBound.value }
            .sorted { $0.dayValue < $1.dayValue }
    }

    func totalCheckIns(on day: GameDay) -> Int {
        allHabits().reduce(0) { partial, habit in
            partial + (log(for: habit, on: day)?.count ?? 0)
        }
    }

    func totalTargets() -> Int {
        allHabits().reduce(0) { $0 + $1.dailyTarget }
    }

    @discardableResult
    func insert(_ habit: Habit) -> Habit {
        context.insert(habit)
        return habit
    }

    func delete(_ habit: Habit) {
        context.delete(habit)
    }
}
