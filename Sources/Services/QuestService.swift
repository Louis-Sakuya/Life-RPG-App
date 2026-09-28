import Foundation
import SwiftData

/// 任务的创建、改期、完成与撤销。所有对 `Quest` 状态的写入都必须走这里，
/// 因为完成一个任务同时牵动流水、玩家计数器、连续状态与当日聚合四处副作用。
@MainActor
final class QuestService {
    private let context: ModelContext
    private let config: GameConfig
    private let calendar: GameCalendar
    private let quests: QuestRepository
    private let records: RecordRepository
    private let rewards: RewardService
    private let lucky: LuckyService
    private let aggregates: DailyAggregateService
    private let engine: RewardEngine

    init(
        context: ModelContext,
        config: GameConfig,
        calendar: GameCalendar,
        rewards: RewardService,
        lucky: LuckyService
    ) {
        self.context = context
        self.config = config
        self.calendar = calendar
        self.quests = QuestRepository(context: context)
        self.records = RecordRepository(context: context)
        self.rewards = rewards
        self.lucky = lucky
        self.aggregates = DailyAggregateService(context: context)
        self.engine = RewardEngine(config: config)
    }

    // MARK: - 创建与编辑

    /// 默认仍由创建日与计划日派生类型。工会发布向导可以传入 `preferredKind`，
    /// 让用户明确张贴到主线或支线栏，而不被日期规则改写展示位置。
    @discardableResult
    func createQuest(
        title: String,
        detail: String = "",
        difficulty: QuestDifficulty = .normal,
        priority: QuestPriority = .normal,
        tags: [String] = [],
        estimatedMinutes: Int = 30,
        scheduledDay: GameDay,
        dueAt: Date? = nil,
        skillShares: [SkillShare] = [],
        preferredKind: QuestKind? = nil
    ) -> Quest {
        let today = calendar.today
        let quest = Quest(
            title: title,
            detail: detail,
            kind: preferredKind ?? Quest.derivedKind(createdDay: today, scheduledDay: scheduledDay, fromTemplate: false),
            difficulty: difficulty,
            priority: priority,
            tags: tags,
            estimatedMinutes: estimatedMinutes,
            createdDay: today,
            scheduledDay: scheduledDay,
            dueAt: dueAt
        )
        quests.insert(quest, skillShares: skillShares)
        aggregates.refresh(day: scheduledDay)
        return quest
    }

    func update(
        _ quest: Quest,
        title: String,
        detail: String,
        difficulty: QuestDifficulty,
        priority: QuestPriority,
        tags: [String],
        estimatedMinutes: Int,
        scheduledDay: GameDay,
        dueAt: Date?,
        skillShares: [SkillShare]
    ) {
        let previousDay = quest.scheduledDay
        quest.title = title
        quest.detail = detail
        quest.difficulty = difficulty
        quest.priority = priority
        quest.tags = tags
        quest.estimatedMinutes = estimatedMinutes
        quest.dueAt = dueAt
        quest.scheduledDay = scheduledDay
        // 改期后重新派生类型，避免"把支线挪到明天"却仍然按支线结算
        if quest.templateID == nil {
            quest.kind = Quest.derivedKind(
                createdDay: quest.createdDay,
                scheduledDay: scheduledDay,
                fromTemplate: false
            )
        }
        quests.applySkillShares(skillShares, to: quest)

        aggregates.refresh(day: previousDay)
        if previousDay != scheduledDay {
            aggregates.refresh(day: scheduledDay)
        }
    }

    func reschedule(_ quest: Quest, to day: GameDay) {
        let previousDay = quest.scheduledDay
        quest.scheduledDay = day
        if quest.templateID == nil {
            quest.kind = Quest.derivedKind(createdDay: quest.createdDay, scheduledDay: day, fromTemplate: false)
        }
        quest.isOverdue = day < calendar.today && quest.status == .pending
        aggregates.refresh(day: previousDay)
        aggregates.refresh(day: day)
    }

    func delete(_ quest: Quest, player: Player) {
        if quest.status == .completed {
            uncomplete(quest, player: player)
        }
        let day = quest.scheduledDay
        quests.delete(quest)
        aggregates.refresh(day: day)
    }

    func cancel(_ quest: Quest, player: Player) {
        if quest.status == .completed {
            uncomplete(quest, player: player)
        }
        quest.status = .cancelled
        aggregates.refresh(day: quest.scheduledDay)
    }

    // MARK: - 完成

    @discardableResult
    func complete(_ quest: Quest, player: Player) -> RewardResult? {
        guard quest.status == .pending else { return nil }
        guard !player.isPaused(calendar.today) else { return nil }

        let now = Date()
        let completedDay = calendar.today
        if let templateID = quest.templateID, let template = quests.template(id: templateID) {
            let doneToday = quests.completedCount(templateID: templateID, on: completedDay)
            guard doneToday < max(1, template.maxCompletionsPerDay) else { return nil }
        }

        quest.status = .completed
        quest.completedAt = now
        quest.completedDay = completedDay
        if completedDay > quest.scheduledDay {
            quest.isOverdue = true
        }

        let template = quest.templateID.flatMap { quests.template(id: $0) }
        if let template {
            template.streak = StreakEngine.advance(template.streak, on: completedDay, calendar: calendar)
            quest.streakAtCompletion = template.streak.current
        }

        let fortune = lucky.rollDayIfNeeded(player: player, on: completedDay)
        let result = engine.evaluate(makeContext(for: quest, player: player, completedAt: now, fortune: fortune))
        rewards.grant(
            result,
            to: player,
            source: .quest,
            sourceID: quest.id,
            title: quest.title,
            on: completedDay
        )
        lucky.rollGrowth(player: player)

        player.totalQuestsCompleted += 1
        if quest.kind == .side {
            player.totalSideQuestsCompleted += 1
        } else {
            player.totalMainQuestsCompleted += 1
        }

        let hour = calendar.logicalHour(of: now)
        player.earliestCompletionHour = min(player.earliestCompletionHour, hour)
        player.latestCompletionHour = max(player.latestCompletionHour, hour)

        aggregates.refresh(day: completedDay)
        if completedDay != quest.scheduledDay {
            aggregates.refresh(day: quest.scheduledDay)
        }
        if let templateID = quest.templateID, let template = quests.template(id: templateID) {
            _ = quests.ensurePendingRepeating(
                template: template,
                on: completedDay,
                calendar: calendar,
                pausedDayValues: player.pausedDaySet
            )
        }
        return result
    }

    /// 撤销完成。经验与金币按流水原样回滚，不重算公式。
    func uncomplete(_ quest: Quest, player: Player) {
        guard quest.status == .completed else { return }
        let completedDay = quest.completedDay ?? calendar.today

        rewards.revertAll(sourceID: quest.id, for: player)

        if let templateID = quest.templateID, let template = quests.template(id: templateID) {
            template.streak = StreakEngine.revert(template.streak, on: completedDay, calendar: calendar)
        }

        player.totalQuestsCompleted = max(0, player.totalQuestsCompleted - 1)
        if quest.kind == .side {
            player.totalSideQuestsCompleted = max(0, player.totalSideQuestsCompleted - 1)
        } else {
            player.totalMainQuestsCompleted = max(0, player.totalMainQuestsCompleted - 1)
        }

        quest.status = .pending
        quest.completedAt = nil
        quest.completedDay = nil
        quest.streakAtCompletion = 0
        quest.isOverdue = quest.scheduledDay < calendar.today

        aggregates.refresh(day: completedDay)
        if completedDay != quest.scheduledDay {
            aggregates.refresh(day: quest.scheduledDay)
        }
    }

    func previewFinish(_ template: QuestTemplate) -> RecurringFinishReward {
        let today = calendar.today
        let duration = RecurringFinishEngine.durationDays(from: template.startDay, to: today, calendar: calendar)
        let completions = quests.completedCount(templateID: template.id)
        return RecurringFinishEngine.evaluate(durationDays: duration, completions: completions)
    }

    /// 结束一趟远行：停生成、取消待办、按持续天数发放归途奖励。
    @discardableResult
    func finishTemplate(_ template: QuestTemplate, player: Player) -> RecurringFinishReward? {
        guard !template.isFinished else { return nil }

        let today = calendar.today
        let reward = previewFinish(template)

        template.finishedDay = today
        template.endDay = today
        template.isActive = false

        for quest in quests.pendingRepeating(templateID: template.id) {
            cancel(quest, player: player)
        }

        rewards.grantFlat(
            exp: reward.exp,
            gold: reward.gold,
            to: player,
            source: .recurringFinish,
            sourceID: template.id,
            sourceRuleID: "recurring_finish",
            title: template.title,
            on: today
        )

        player.totalRecurringSeriesFinished += 1
        player.longestRecurringSeriesDays = max(player.longestRecurringSeriesDays, reward.durationDays)
        return reward
    }

    func toggleCompletion(_ quest: Quest, player: Player) -> RewardResult? {
        if quest.status == .completed {
            uncomplete(quest, player: player)
            return nil
        }
        return complete(quest, player: player)
    }

    // MARK: - 预览

    /// 完成前的预估收益，用于任务卡片上直接展示"做完能拿多少"。
    /// 让玩家在决定先做哪件事之前就看到差异，是奖励系统产生引导力的前提。
    func previewReward(for quest: Quest, player: Player) -> RewardResult {
        let fortune = lucky.activeFortune(for: player, on: calendar.today)
        return engine.preview(makeContext(for: quest, player: player, completedAt: Date(), fortune: fortune))
    }

    // MARK: - 内部

    private func makeContext(for quest: Quest, player: Player, completedAt: Date, fortune: FortuneTier?) -> RewardContext {
        let template = quest.templateID.flatMap { quests.template(id: $0) }
        let shares = quests.skillShares(of: quest)
        let profile = RewardGrowthProfile.make(shares: shares, player: player, context: context, config: config)
        return RewardContext(
            difficulty: quest.difficulty,
            priority: quest.priority,
            estimatedMinutes: quest.estimatedMinutes,
            isPlannedAhead: quest.isPlannedAhead,
            scheduledDay: quest.scheduledDay,
            completedDay: quest.completedDay ?? calendar.today,
            dueAt: quest.dueAt,
            completedAt: completedAt,
            forceOverdue: quest.isOverdue,
            consecutiveStreak: template?.streak.current ?? quest.streakAtCompletion,
            globalStreakDays: player.loginStreakCurrent,
            skillShares: shares,
            fortune: fortune,
            skillLevels: profile.skillLevels,
            skillAffinities: profile.skillAffinities,
            statLevels: profile.statLevels
        )
    }
}
