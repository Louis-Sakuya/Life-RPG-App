import Foundation
import SwiftData

/// 把数据库状态摊平成 `MetricsSnapshot`。
///
/// 之所以值得单独一层：解锁引擎、统计页、未来的 AI 助手都需要同一份统计口径，
/// 如果各自去查库，口径迟早会漂移。
@MainActor
struct MetricsService {
    private let context: ModelContext
    private let config: GameConfig
    private let calendar: GameCalendar

    init(context: ModelContext, config: GameConfig, calendar: GameCalendar) {
        self.context = context
        self.config = config
        self.calendar = calendar
    }

    func snapshot(player: Player) -> MetricsSnapshot {
        let skills = SkillRepository(context: context)
        let habits = HabitRepository(context: context)
        let progression = ProgressionRepository(context: context)

        var snapshot = MetricsSnapshot()

        snapshot.scalars[MetricKey.totalQuestsCompleted] = Double(player.totalQuestsCompleted)
        snapshot.scalars[MetricKey.totalMainQuestsCompleted] = Double(player.totalMainQuestsCompleted)
        snapshot.scalars[MetricKey.totalSideQuestsCompleted] = Double(player.totalSideQuestsCompleted)
        snapshot.scalars[MetricKey.totalHabitCheckIns] = Double(player.totalHabitCheckIns)
        snapshot.scalars[MetricKey.playerLevel] = Double(config.playerCurve.level(forTotalEXP: player.totalEXP))
        snapshot.scalars[MetricKey.loginStreak] = Double(player.loginStreakCurrent)
        snapshot.scalars[MetricKey.bestLoginStreak] = Double(player.loginStreakBest)
        snapshot.scalars[MetricKey.totalFocusMinutes] = Double(player.totalFocusMinutes)
        snapshot.scalars[MetricKey.totalStudyMinutes] = Double(player.totalStudyMinutes)
        snapshot.scalars[MetricKey.totalEXPEarned] = Double(player.totalEXPEarned)
        snapshot.scalars[MetricKey.totalGoldEarned] = Double(player.totalGoldEarned)
        snapshot.scalars[MetricKey.totalDays] = Double(player.totalDaysPlayed)
        snapshot.scalars[MetricKey.perfectDays] = Double(player.perfectDays)
        snapshot.scalars[MetricKey.earliestCompletionHour] = Double(player.earliestCompletionHour)
        snapshot.scalars[MetricKey.latestCompletionHour] = Double(player.latestCompletionHour)

        for skill in skills.allSkills(includeArchived: true) {
            snapshot.skillLevels[skill.name] = Double(config.skillCurve.level(forTotalEXP: skill.totalEXP))
        }
        snapshot.scalars[MetricKey.maxSkillLevel] = snapshot.skillLevels.values.max() ?? 0

        for habit in habits.allHabits(includeArchived: true) {
            snapshot.habitStreaks[habit.name] = Double(max(habit.streakCurrent, habit.streakBest))
        }

        let unlocks = progression.allUnlocks()
        snapshot.scalars[MetricKey.recurringSeriesFinished] = Double(player.totalRecurringSeriesFinished)
        snapshot.scalars[MetricKey.longestRecurringSeriesDays] = Double(player.longestRecurringSeriesDays)
        snapshot.scalars[MetricKey.recurringJourneys] = Double(
            QuestRepository(context: context).allTemplates().reduce(0) { $0 + $1.completedJourneys }
        )
        snapshot.scalars[MetricKey.achievementsUnlocked] = Double(unlocks.filter { $0.kind == .achievement }.count)
        snapshot.scalars[MetricKey.challengesCompleted] = Double(
            progression.allChallenges(includeArchived: true).filter(\.isCompleted).count
        )

        return snapshot
    }
}
