import XCTest
@testable import LifeRPG

final class RewardEngineTests: XCTestCase {

    private let engine = RewardEngine(balance: .fallback, modifiers: .fallback)
    private let today = GameDay(year: 2026, month: 8, day: 4)
    private let yesterday = GameDay(year: 2026, month: 8, day: 3)

    private func context(
        difficulty: QuestDifficulty = .normal,
        priority: QuestPriority = .normal,
        minutes: Int = 60,
        plannedAhead: Bool = true,
        scheduled: GameDay? = nil,
        completed: GameDay? = nil,
        consecutive: Int = 0,
        globalStreak: Int = 0,
        shares: [SkillShare] = []
    ) -> RewardContext {
        RewardContext(
            difficulty: difficulty,
            priority: priority,
            estimatedMinutes: minutes,
            isPlannedAhead: plannedAhead,
            scheduledDay: scheduled ?? today,
            completedDay: completed ?? today,
            consecutiveStreak: consecutive,
            globalStreakDays: globalStreak,
            skillShares: shares
        )
    }

    // MARK: - 基础

    func testDurationFactorIsClamped() {
        XCTAssertEqual(engine.durationFactor(minutes: 0), 1.0, accuracy: 0.001)
        XCTAssertEqual(engine.durationFactor(minutes: 60), 1.5, accuracy: 0.001)
        // 上限 3.0，再长的任务不会无限膨胀收益
        XCTAssertEqual(engine.durationFactor(minutes: 6000), 3.0, accuracy: 0.001)
    }

    func testBaseRewardUsesDifficultyTable() {
        let result = engine.evaluate(context(difficulty: .normal, minutes: 0))
        XCTAssertEqual(result.baseEXP, 35, accuracy: 0.001)
        XCTAssertEqual(result.baseGold, 17.5, accuracy: 0.001)
    }

    // MARK: - 分组互斥

    /// planning 组只能命中一条：提前规划与当天临时描述的是同一个维度
    func testPlanningModifiersAreMutuallyExclusive() {
        let planned = engine.evaluate(context(plannedAhead: true))
        let sameDay = engine.evaluate(context(plannedAhead: false))

        XCTAssertEqual(planned.appliedModifiers.filter { $0.group == "planning" }.count, 1)
        XCTAssertEqual(sameDay.appliedModifiers.filter { $0.group == "planning" }.count, 1)
        XCTAssertTrue(planned.appliedModifiers.contains { $0.id == ModifierID.plannedAhead })
        XCTAssertTrue(sameDay.appliedModifiers.contains { $0.id == ModifierID.sameDay })
    }

    func testEveryGroupAppearsAtMostOnce() {
        let result = engine.evaluate(
            context(difficulty: .epic, priority: .critical, plannedAhead: true, consecutive: 10)
        )
        let groups = result.appliedModifiers.map(\.group)
        XCTAssertEqual(groups.count, Set(groups).count)
    }

    // MARK: - 乘数

    func testBestCaseMultiplier() {
        // 提前规划 +0.2、按时完成 +0.2、五星 +0.3、连续 +0.1 → 1.8
        let result = engine.evaluate(
            context(difficulty: .epic, priority: .critical, plannedAhead: true, consecutive: 5)
        )
        XCTAssertEqual(result.multiplier, 1.8, accuracy: 0.001)
    }

    func testWorstCaseMultiplier() {
        // 当天临时 -0.2、延期完成 -0.5 → 0.3
        let result = engine.evaluate(
            context(plannedAhead: false, scheduled: yesterday, completed: today)
        )
        XCTAssertEqual(result.multiplier, 0.3, accuracy: 0.001)
    }

    func testMultiplierNeverExceedsClamp() {
        for difficulty in QuestDifficulty.allCases {
            for priority in QuestPriority.allCases {
                for planned in [true, false] {
                    let result = engine.evaluate(
                        context(difficulty: difficulty, priority: priority, plannedAhead: planned, consecutive: 99)
                    )
                    XCTAssertGreaterThanOrEqual(result.multiplier, BalanceConfig.fallback.multiplierClamp.min)
                    XCTAssertLessThanOrEqual(result.multiplier, BalanceConfig.fallback.multiplierClamp.max)
                }
            }
        }
    }

    /// 连续加成是独立乘数，不能被上面的夹逼吃掉
    func testStreakMultiplierIsAppliedOutsideClamp() {
        let noStreak = engine.evaluate(context(plannedAhead: false, scheduled: yesterday, completed: today))
        let withStreak = engine.evaluate(
            context(plannedAhead: false, scheduled: yesterday, completed: today, globalStreak: 100)
        )
        XCTAssertEqual(noStreak.multiplier, withStreak.multiplier, accuracy: 0.001)
        XCTAssertEqual(withStreak.streakMultiplier, 1.5, accuracy: 0.001)
        XCTAssertGreaterThan(withStreak.exp, noStreak.exp)
    }

    func testStreakTiersPickHighestSatisfied() {
        let tiers = BalanceConfig.fallback.streakTiers
        XCTAssertEqual(StreakEngine.multiplier(forDays: 0, tiers: tiers), 1.0, accuracy: 0.001)
        XCTAssertEqual(StreakEngine.multiplier(forDays: 6, tiers: tiers), 1.0, accuracy: 0.001)
        XCTAssertEqual(StreakEngine.multiplier(forDays: 7, tiers: tiers), 1.1, accuracy: 0.001)
        XCTAssertEqual(StreakEngine.multiplier(forDays: 29, tiers: tiers), 1.1, accuracy: 0.001)
        XCTAssertEqual(StreakEngine.multiplier(forDays: 100, tiers: tiers), 1.5, accuracy: 0.001)
        XCTAssertEqual(StreakEngine.multiplier(forDays: 5000, tiers: tiers), 1.5, accuracy: 0.001)
    }

    // MARK: - 规划引导

    /// 提前规划仍应明显高于当天临时，但支线不再打五折
    func testPlanningGapIsSubstantial() {
        let planned = engine.evaluate(context(plannedAhead: true))
        let impromptu = engine.evaluate(context(plannedAhead: false))
        XCTAssertGreaterThan(planned.exp, impromptu.exp)
        XCTAssertGreaterThan(Double(planned.exp), Double(impromptu.exp) * 1.3)
    }

    // MARK: - 技能分配

    func testSkillEXPFollowsShares() {
        let programming = UUID()
        let gameDesign = UUID()
        let result = engine.evaluate(
            context(shares: [
                SkillShare(skillID: programming, expShare: 1.0),
                SkillShare(skillID: gameDesign, expShare: 0.5)
            ])
        )
        XCTAssertEqual(result.skillEXP[programming], result.exp)
        XCTAssertEqual(result.skillEXP[gameDesign], Int((Double(result.exp) * 0.5).rounded()))
    }

    func testZeroShareSkillsAreSkipped() {
        let skill = UUID()
        let result = engine.evaluate(context(shares: [SkillShare(skillID: skill, expShare: 0)]))
        XCTAssertNil(result.skillEXP[skill])
    }

    func testDuplicateSkillSharesAccumulate() {
        let skill = UUID()
        let result = engine.evaluate(context(shares: [
            SkillShare(skillID: skill, expShare: 0.5),
            SkillShare(skillID: skill, expShare: 0.5)
        ]))
        XCTAssertEqual(result.skillEXP.count, 1)
        XCTAssertEqual(result.skillEXP[skill], Int((Double(result.exp) * 0.5).rounded()) * 2)
    }

    // MARK: - 习惯

    func testHabitRewardIgnoresQuestModifiers() {
        let result = engine.evaluateHabit(streakDays: 0, globalStreakDays: 0, skillShares: [])
        XCTAssertTrue(result.appliedModifiers.isEmpty)
        XCTAssertEqual(result.exp, BalanceConfig.fallback.habitReward.baseEXP)
        XCTAssertEqual(result.gold, BalanceConfig.fallback.habitReward.baseGold)
    }

    func testHabitRewardScalesWithStreak() {
        let plain = engine.evaluateHabit(streakDays: 0, globalStreakDays: 0, skillShares: [])
        let streaked = engine.evaluateHabit(streakDays: 100, globalStreakDays: 0, skillShares: [])
        XCTAssertGreaterThan(streaked.exp, plain.exp)
    }

    /// 习惯的收益必须显著低于任务，否则玩家会用一键打卡绕过任务系统
    func testHabitRewardStaysBelowQuestReward() {
        let habit = engine.evaluateHabit(streakDays: 0, globalStreakDays: 0, skillShares: [])
        let quest = engine.evaluate(context())
        XCTAssertLessThan(habit.exp, quest.exp)
    }

    /// 幸运日加成是独立乘数，不能被夹逼吃掉
    func testFortuneMultipliesOutsideClamp() {
        let fortune = FortuneConfig.fallback.tier(id: "fortune_2")
        let clamped = engine.evaluate(context(plannedAhead: false, scheduled: yesterday, completed: today))
        var boostedContext = context(plannedAhead: false, scheduled: yesterday, completed: today)
        boostedContext.fortune = fortune
        let boosted = engine.evaluate(boostedContext)

        XCTAssertEqual(clamped.multiplier, boosted.multiplier, accuracy: 0.001)
        XCTAssertEqual(boosted.fortuneMultiplier, 1.25, accuracy: 0.001)
        XCTAssertGreaterThan(boosted.exp, clamped.exp)
        XCTAssertGreaterThan(boosted.gold, clamped.gold)
    }

    func testHigherSkillLevelIncreasesQuestReward() {
        let skill = UUID()
        let shares = [SkillShare(skillID: skill, expShare: 1)]
        var plain = context(shares: shares)
        plain.skillLevels = [skill: 1]
        var trained = context(shares: shares)
        trained.skillLevels = [skill: 11]
        let low = engine.evaluate(plain)
        let high = engine.evaluate(trained)
        XCTAssertEqual(low.skillLevelMultiplier, 1, accuracy: 0.0001)
        XCTAssertEqual(high.skillLevelMultiplier, 1.2, accuracy: 0.0001)
        XCTAssertGreaterThan(high.exp, low.exp)
        XCTAssertGreaterThan(high.gold, low.gold)
    }

    func testMatchingStatAcceleratesSkillXP() {
        let skill = UUID()
        var plain = context(shares: [SkillShare(skillID: skill, expShare: 1)])
        plain.skillAffinities = [skill: [StatAffinity(stat: .mind, weight: 1)]]
        plain.statLevels = [.mind: 1]
        var boosted = plain
        boosted.statLevels = [.mind: 11]
        let low = engine.evaluate(plain)
        let high = engine.evaluate(boosted)
        XCTAssertEqual(low.exp, high.exp)
        XCTAssertGreaterThan(high.skillEXP[skill] ?? 0, low.skillEXP[skill] ?? 0)
    }
}
