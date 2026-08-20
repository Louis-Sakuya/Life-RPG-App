import Foundation
import SwiftData

/// 维护 `DailyRecord` 里与"当天有多少事要做、做完了多少"相关的字段。
///
/// EXP 与 Gold 由 `RewardService` 在流水落账时增量更新；这里负责的计数字段则是
/// 重算式的，因为任务可能被改期、删除或取消完成，增量维护极易漂移。
/// 重算的成本只有 O(当天任务数)，完全可以接受。
@MainActor
struct DailyAggregateService {
    private let quests: QuestRepository
    private let habits: HabitRepository
    private let records: RecordRepository

    init(context: ModelContext) {
        self.quests = QuestRepository(context: context)
        self.habits = HabitRepository(context: context)
        self.records = RecordRepository(context: context)
    }

    @discardableResult
    func refresh(day: GameDay) -> DailyRecord {
        let record = records.ensureRecord(on: day)
        let dayQuests = quests.quests(on: day)

        record.questsPlanned = dayQuests.count
        record.questsCompleted = dayQuests.filter { $0.status == .completed }.count
        record.mainQuestsCompleted = dayQuests.filter { $0.status == .completed && $0.kind != .side }.count
        record.sideQuestsCompleted = dayQuests.filter { $0.status == .completed && $0.kind == .side }.count

        let activeHabits = habits.allHabits()
        record.habitTargets = activeHabits.reduce(0) { $0 + $1.dailyTarget }
        record.habitCheckIns = activeHabits.reduce(0) { partial, habit in
            partial + (habits.log(for: habit, on: day)?.count ?? 0)
        }

        record.updatedAt = Date()
        return record
    }

    func addFocusMinutes(_ minutes: Int, on day: GameDay) {
        let record = records.ensureRecord(on: day)
        record.focusMinutes += max(0, minutes)
        record.updatedAt = Date()
    }

    func addStudyMinutes(_ minutes: Int, on day: GameDay) {
        let record = records.ensureRecord(on: day)
        record.studyMinutes += max(0, minutes)
        record.updatedAt = Date()
    }
}
