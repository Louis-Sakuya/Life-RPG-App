import Foundation

/// 奖励计算的输入。全部是值类型，不含任何 SwiftData 引用，因此引擎可以脱离模拟器单测。
struct RewardContext: Sendable {
    var difficulty: QuestDifficulty
    var priority: QuestPriority
    var estimatedMinutes: Int
    /// 是否提前规划。由创建日与计划日的关系派生，重复任务恒为 true。
    var isPlannedAhead: Bool
    var scheduledDay: GameDay
    var completedDay: GameDay
    var dueAt: Date?
    var completedAt: Date
    /// 周期任务进入延期周后，即使当天完成也按延期结算
    var forceOverdue: Bool
    /// 同一重复序列的连续完成次数
    var consecutiveStreak: Int
    /// 全局连续天数（登录连续），决定 streakMultiplier
    var globalStreakDays: Int
    var skillShares: [SkillShare]
    var fortune: FortuneTier?
    /// 关联技能当前等级，用于提高任务经验与金币
    var skillLevels: [UUID: Int]
    /// 关联技能的属性亲和，用于属性加速技能经验
    var skillAffinities: [UUID: [StatAffinity]]
    /// 玩家五个核心属性的有效等级（训练等级 + 加点）
    var statLevels: [CoreStatID: Int]

    init(
        difficulty: QuestDifficulty = .normal,
        priority: QuestPriority = .normal,
        estimatedMinutes: Int = 30,
        isPlannedAhead: Bool = false,
        scheduledDay: GameDay,
        completedDay: GameDay,
        dueAt: Date? = nil,
        completedAt: Date = Date(),
        forceOverdue: Bool = false,
        consecutiveStreak: Int = 0,
        globalStreakDays: Int = 0,
        skillShares: [SkillShare] = [],
        fortune: FortuneTier? = nil,
        skillLevels: [UUID: Int] = [:],
        skillAffinities: [UUID: [StatAffinity]] = [:],
        statLevels: [CoreStatID: Int] = [:]
    ) {
        self.difficulty = difficulty
        self.priority = priority
        self.estimatedMinutes = estimatedMinutes
        self.isPlannedAhead = isPlannedAhead
        self.scheduledDay = scheduledDay
        self.completedDay = completedDay
        self.dueAt = dueAt
        self.completedAt = completedAt
        self.forceOverdue = forceOverdue
        self.consecutiveStreak = consecutiveStreak
        self.globalStreakDays = globalStreakDays
        self.skillShares = skillShares
        self.fortune = fortune
        self.skillLevels = skillLevels
        self.skillAffinities = skillAffinities
        self.statLevels = statLevels
    }
}

struct AppliedModifier: Hashable, Identifiable, Sendable {
    var id: String
    var group: String
    var label: String
    var value: Double

    var signedPercentText: String {
        let percent = Int((value * 100).rounded())
        return percent >= 0 ? "+\(percent)%" : "\(percent)%"
    }
}

struct RewardResult: Sendable {
    var baseEXP: Double
    var baseGold: Double
    var durationFactor: Double
    var appliedModifiers: [AppliedModifier]
    /// 加成叠加并夹逼后的乘数
    var multiplier: Double
    /// 连续天数带来的独立乘数，不参与夹逼
    var streakMultiplier: Double
    var fortuneMultiplier: Double
    var fortuneLabel: String?
    /// 关联技能等级对整笔任务奖励的乘数
    var skillLevelMultiplier: Double
    var exp: Int
    var gold: Int
    var skillEXP: [UUID: Int]

    var breakdownText: String {
        var parts = [L10n.format("reward.base", baseEXP)]
        if durationFactor != 1.0 {
            parts.append(L10n.format("reward.duration", durationFactor))
        }
        for modifier in appliedModifiers {
            parts.append("\(modifier.localizedLabel) \(modifier.signedPercentText)")
        }
        if streakMultiplier != 1.0 {
            parts.append(L10n.format("reward.streak", streakMultiplier))
        }
        if fortuneMultiplier != 1.0, let fortuneLabel {
            parts.append("\(fortuneLabel) ×\(String(format: "%.2f", fortuneMultiplier))")
        }
        if skillLevelMultiplier != 1.0 {
            parts.append(L10n.format("reward.skill_level", skillLevelMultiplier))
        }
        parts.append("→ \(exp) EXP / \(gold) G")
        return parts.joined(separator: "  ")
    }
}

/// 奖励引擎。
///
/// 关键设计：加成按 `group` 互斥。`planned_ahead(+20%)` 与 `same_day(-20%)` 描述的是
/// 同一个维度，同时生效在语义上矛盾；分组保证任何时刻每个维度只有一条加成落地。
/// 组内若意外命中多条，取绝对值最大的一条（惩罚优先），保证行为可预测。
struct RewardEngine: Sendable {
    let balance: BalanceConfig
    let modifiers: ModifierConfig

    init(balance: BalanceConfig, modifiers: ModifierConfig) {
        self.balance = balance
        self.modifiers = modifiers
    }

    init(config: GameConfig) {
        self.init(balance: config.balance, modifiers: config.modifiers)
    }

    // MARK: - 任务奖励

    func evaluate(_ context: RewardContext) -> RewardResult {
        let durationFactor = durationFactor(minutes: context.estimatedMinutes)
        let baseEXP = balance.baseEXP(for: context.difficulty) * durationFactor
        let baseGold = baseEXP * balance.goldRatio

        let applied = resolveModifiers(for: context)
        let rawMultiplier = 1.0 + applied.reduce(0.0) { $0 + $1.value }
        let multiplier = min(balance.multiplierClamp.max, max(balance.multiplierClamp.min, rawMultiplier))
        let streakMultiplier = StreakEngine.multiplier(forDays: context.globalStreakDays, tiers: balance.streakTiers)
        let fortuneXP = context.fortune?.xpMultiplier ?? 1
        let fortuneGold = context.fortune?.goldMultiplier ?? 1
        let fortuneLabel = context.fortune.map(\.localizedName)
        let skillLevelMultiplier = ProgressionEngine.questRewardMultiplier(
            shares: context.skillShares,
            levels: context.skillLevels,
            perLevel: balance.skillQuestBonusPerLevel,
            cap: balance.skillQuestBonusMax
        )

        let exp = Int((baseEXP * multiplier * streakMultiplier * fortuneXP * skillLevelMultiplier).rounded()) + (context.fortune?.bonusEXP ?? 0)
        let gold = Int((baseGold * multiplier * streakMultiplier * fortuneGold * skillLevelMultiplier).rounded()) + (context.fortune?.bonusGold ?? 0)

        var skillEXP: [UUID: Int] = [:]
        for share in context.skillShares where share.expShare > 0 {
            let growth = ProgressionEngine.skillXPMultiplier(
                affinities: context.skillAffinities[share.skillID] ?? [],
                statLevels: context.statLevels,
                perLevel: balance.statSkillXPBonusPerLevel,
                cap: balance.statSkillXPBonusMax
            )
            let value = Int((Double(exp) * share.expShare * growth).rounded())
            guard value > 0 else { continue }
            skillEXP[share.skillID, default: 0] += value
        }

        return RewardResult(
            baseEXP: baseEXP,
            baseGold: baseGold,
            durationFactor: durationFactor,
            appliedModifiers: applied,
            multiplier: multiplier,
            streakMultiplier: streakMultiplier,
            fortuneMultiplier: fortuneXP,
            fortuneLabel: fortuneLabel,
            skillLevelMultiplier: skillLevelMultiplier,
            exp: max(0, exp),
            gold: max(0, gold),
            skillEXP: skillEXP
        )
    }

    /// 完成前的预估。假设玩家现在就按时完成，用于任务卡片上展示"预计收益"。
    func preview(_ context: RewardContext) -> RewardResult {
        evaluate(context)
    }

    // MARK: - 习惯奖励

    /// 习惯不参与难度 / 时长 / 准时度体系，只吃连续加成。
    /// 交互成本低就应该收益低，否则玩家会用打卡刷掉任务系统的意义。
    func evaluateHabit(
        streakDays: Int,
        globalStreakDays: Int,
        skillShares: [SkillShare],
        skillAffinities: [UUID: [StatAffinity]] = [:],
        statLevels: [CoreStatID: Int] = [:]
    ) -> RewardResult {
        let streakMultiplier = StreakEngine.multiplier(
            forDays: max(streakDays, globalStreakDays),
            tiers: balance.streakTiers
        )
        let exp = Int((Double(balance.habitReward.baseEXP) * streakMultiplier).rounded())
        let gold = Int((Double(balance.habitReward.baseGold) * streakMultiplier).rounded())

        var skillEXP: [UUID: Int] = [:]
        for share in skillShares where share.expShare > 0 {
            let growth = ProgressionEngine.skillXPMultiplier(
                affinities: skillAffinities[share.skillID] ?? [],
                statLevels: statLevels,
                perLevel: balance.statSkillXPBonusPerLevel,
                cap: balance.statSkillXPBonusMax
            )
            let value = Int((Double(exp) * share.expShare * growth).rounded())
            guard value > 0 else { continue }
            skillEXP[share.skillID, default: 0] += value
        }

        return RewardResult(
            baseEXP: Double(balance.habitReward.baseEXP),
            baseGold: Double(balance.habitReward.baseGold),
            durationFactor: 1.0,
            appliedModifiers: [],
            multiplier: 1.0,
            streakMultiplier: streakMultiplier,
            fortuneMultiplier: 1,
            fortuneLabel: nil,
            skillLevelMultiplier: 1,
            exp: exp,
            gold: gold,
            skillEXP: skillEXP
        )
    }

    // MARK: - 升级奖励

    func levelUpGold(forLevel level: Int) -> Int {
        balance.levelUpReward.goldBase + balance.levelUpReward.goldPerLevel * level
    }

    // MARK: - 内部

    func durationFactor(minutes: Int) -> Double {
        let raw = 1.0 + (Double(max(0, minutes)) / 60.0) * balance.durationFactor.bonusPerHour
        return min(balance.durationFactor.max, max(balance.durationFactor.min, raw))
    }

    /// 判定命中哪些加成 id。判定条件属于业务规则写在代码里，
    /// 数值与分组属于平衡参数写在 JSON 里，这条线就是两者的边界。
    private func candidateIDs(for context: RewardContext) -> [String] {
        var ids: [String] = []

        ids.append(context.isPlannedAhead ? ModifierID.plannedAhead : ModifierID.sameDay)

        if context.forceOverdue {
            ids.append(ModifierID.overdue)
        } else if let dueAt = context.dueAt {
            ids.append(context.completedAt <= dueAt ? ModifierID.onTime : ModifierID.overdue)
        } else if context.completedDay > context.scheduledDay {
            ids.append(ModifierID.overdue)
        } else {
            ids.append(ModifierID.onTime)
        }

        if context.difficulty == .epic || context.priority == .critical {
            ids.append(ModifierID.fiveStar)
        }

        if context.consecutiveStreak >= 2 {
            ids.append(ModifierID.consecutive)
        }

        return ids
    }

    private func resolveModifiers(for context: RewardContext) -> [AppliedModifier] {
        let candidates = candidateIDs(for: context).compactMap { modifiers.modifier(id: $0) }
        var byGroup: [String: RewardModifier] = [:]
        for candidate in candidates {
            guard let existing = byGroup[candidate.group] else {
                byGroup[candidate.group] = candidate
                continue
            }
            if abs(candidate.value) > abs(existing.value) {
                byGroup[candidate.group] = candidate
            }
        }
        return byGroup.values
            .sorted { $0.id < $1.id }
            .map { AppliedModifier(id: $0.id, group: $0.group, label: $0.label, value: $0.value) }
    }
}
