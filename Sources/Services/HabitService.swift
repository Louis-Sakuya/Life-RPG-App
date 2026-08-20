import Foundation
import SwiftData

/// 习惯打卡。
///
/// 关键规则：奖励只在**达成当日目标的那一次**发放，而不是每次点击都发。
/// 否则"每天喝水 8 杯"这类多次目标的收益会是单次目标的 8 倍，
/// 玩家会通过把目标拆细来刷经验。
@MainActor
final class HabitService {
    private let context: ModelContext
    private let config: GameConfig
    private let calendar: GameCalendar
    private let habits: HabitRepository
    private let rewards: RewardService
    private let aggregates: DailyAggregateService
    private let engine: RewardEngine

    init(context: ModelContext, config: GameConfig, calendar: GameCalendar, rewards: RewardService) {
        self.context = context
        self.config = config
        self.calendar = calendar
        self.habits = HabitRepository(context: context)
        self.rewards = rewards
        self.aggregates = DailyAggregateService(context: context)
        self.engine = RewardEngine(config: config)
    }

    // MARK: - 打卡

    @discardableResult
    func checkIn(_ habit: Habit, player: Player, on day: GameDay? = nil) -> RewardResult? {
        let targetDay = day ?? calendar.today
        let log = habits.ensureLog(for: habit, on: targetDay)
        guard log.count < habit.dailyTarget else { return nil }

        log.count += 1
        log.updatedAt = Date()
        habit.totalCheckIns += 1
        player.totalHabitCheckIns += 1

        var result: RewardResult?
        if log.count >= habit.dailyTarget {
            habit.streak = StreakEngine.advance(habit.streak, on: targetDay, calendar: calendar)
            let reward = engine.evaluateHabit(
                streakDays: habit.streakCurrent,
                globalStreakDays: player.loginStreakCurrent,
                skillShares: habit.skillShares
            )
            rewards.grant(
                reward,
                to: player,
                source: .habit,
                sourceID: habit.id,
                title: habit.name,
                on: targetDay
            )
            result = reward
        }

        aggregates.refresh(day: targetDay)
        return result
    }

    func undoCheckIn(_ habit: Habit, player: Player, on day: GameDay? = nil) {
        let targetDay = day ?? calendar.today
        guard let log = habits.log(for: habit, on: targetDay), log.count > 0 else { return }

        let wasComplete = log.count >= habit.dailyTarget
        log.count -= 1
        log.updatedAt = Date()
        habit.totalCheckIns = max(0, habit.totalCheckIns - 1)
        player.totalHabitCheckIns = max(0, player.totalHabitCheckIns - 1)

        if wasComplete {
            rewards.revertAll(sourceID: habit.id, on: targetDay, for: player)
            habit.streak = StreakEngine.revert(habit.streak, on: targetDay, calendar: calendar)
        }

        aggregates.refresh(day: targetDay)
    }

    /// 一键切换：未完成则补满当天目标，已完成则清空。用于首页的快速打卡手势。
    func toggle(_ habit: Habit, player: Player, on day: GameDay? = nil) {
        let targetDay = day ?? calendar.today
        let current = habits.log(for: habit, on: targetDay)?.count ?? 0
        if current >= habit.dailyTarget {
            for _ in 0..<current {
                undoCheckIn(habit, player: player, on: targetDay)
            }
        } else {
            for _ in current..<habit.dailyTarget {
                checkIn(habit, player: player, on: targetDay)
            }
        }
    }

    func progress(for habit: Habit, on day: GameDay? = nil) -> Int {
        habits.log(for: habit, on: day ?? calendar.today)?.count ?? 0
    }

    // MARK: - 管理

    @discardableResult
    func createHabit(
        name: String,
        iconName: String,
        colorHex: String,
        dailyTarget: Int,
        reminderHour: Int = -1,
        reminderMinute: Int = 0,
        skillShares: [SkillShare] = []
    ) -> Habit {
        let habit = Habit(
            name: name,
            iconName: iconName,
            colorHex: colorHex,
            dailyTarget: dailyTarget,
            sortOrder: habits.allHabits(includeArchived: true).count
        )
        habit.reminderHour = reminderHour
        habit.reminderMinute = reminderMinute
        habit.skillShares = skillShares
        habits.insert(habit)
        aggregates.refresh(day: calendar.today)
        return habit
    }

    func delete(_ habit: Habit) {
        habits.delete(habit)
        aggregates.refresh(day: calendar.today)
    }
}
