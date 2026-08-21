import XCTest
@testable import LifeRPG

/// 直接校验仓库里真实的配置表。
/// 数值驱动架构的代价是"改 JSON 不会触发编译错误"，这组测试就是用来补上那道防线的。
final class ConfigTests: XCTestCase {

    private var config: GameConfig {
        GameConfig.load(bundle: Bundle(for: ConfigTests.self))
    }

    func testAllConfigFilesLoadWithoutIssues() {
        let config = self.config
        XCTAssertTrue(config.loadIssues.isEmpty, "配置加载问题：\(config.loadIssues)")
    }

    func testBalanceCoversEveryDifficulty() {
        let balance = config.balance
        for difficulty in QuestDifficulty.allCases {
            XCTAssertNotNil(
                balance.difficultyBaseEXP[String(difficulty.rawValue)],
                "difficultyBaseEXP 缺少难度 \(difficulty.rawValue)"
            )
        }
    }

    func testBalanceValuesAreSane() {
        let balance = config.balance
        XCTAssertGreaterThan(balance.goldRatio, 0)
        XCTAssertLessThan(balance.multiplierClamp.min, balance.multiplierClamp.max)
        XCTAssertGreaterThanOrEqual(balance.durationFactor.min, 1.0)
        XCTAssertGreaterThan(balance.playerCurve.base, 0)
        XCTAssertGreaterThan(balance.skillCurve.base, 0)
        XCTAssertGreaterThan(balance.statCurve.base, 0)
        XCTAssertGreaterThan(balance.playerCurve.maxLevel, 1)
        XCTAssertFalse(balance.streakTiers.isEmpty)
        XCTAssertGreaterThanOrEqual(balance.initialSkillSlots, 1)
        XCTAssertGreaterThan(balance.statSkillXPBonusPerLevel, 0)
        XCTAssertGreaterThan(balance.skillQuestBonusPerLevel, 0)
        XCTAssertGreaterThanOrEqual(balance.statSkillXPBonusMax, 1)
        XCTAssertGreaterThanOrEqual(balance.skillQuestBonusMax, 1)
    }

    /// 连续档位必须随天数单调递增，否则"连续更久反而加成更低"
    func testStreakTiersAreMonotonic() {
        let tiers = config.balance.streakTiers.sorted { $0.days < $1.days }
        var previousMultiplier = 1.0
        for tier in tiers {
            XCTAssertGreaterThanOrEqual(tier.multiplier, previousMultiplier)
            previousMultiplier = tier.multiplier
        }
    }

    // MARK: - 加成表

    /// 代码里引用的每个加成 id 都必须在 JSON 里存在，否则那条加成会静默失效
    func testEveryReferencedModifierExists() {
        let modifiers = config.modifiers
        let required = [
            ModifierID.plannedAhead, ModifierID.sameDay,
            ModifierID.onTime, ModifierID.overdue,
            ModifierID.fiveStar, ModifierID.consecutive
        ]
        for id in required {
            XCTAssertNotNil(modifiers.modifier(id: id), "modifiers.json 缺少 \(id)")
        }
    }

    func testModifierIDsAreUnique() {
        let ids = config.modifiers.modifiers.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    /// 规划与准时这两组必须各自成对，否则分组互斥的语义会退化成单边加成
    func testOpposingModifiersShareGroup() {
        let modifiers = config.modifiers
        XCTAssertEqual(
            modifiers.modifier(id: ModifierID.plannedAhead)?.group,
            modifiers.modifier(id: ModifierID.sameDay)?.group
        )
        XCTAssertEqual(
            modifiers.modifier(id: ModifierID.onTime)?.group,
            modifiers.modifier(id: ModifierID.overdue)?.group
        )
        XCTAssertGreaterThan(modifiers.modifier(id: ModifierID.plannedAhead)?.value ?? 0, 0)
        XCTAssertLessThan(modifiers.modifier(id: ModifierID.sameDay)?.value ?? 0, 0)
    }

    // MARK: - 解锁规则

    func testUnlockRuleIDsAreUnique() {
        let ids = config.unlocks.rules.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testEveryUnlockRuleHasConditions() {
        for rule in config.unlocks.rules {
            XCTAssertFalse(rule.conditions.isEmpty, "规则 \(rule.id) 没有任何条件，永远不会解锁")
        }
    }

    /// 规则里引用的称号必须真实存在，否则解锁时会发一个空称号
    func testRewardedTitlesExist() {
        let titleIDs = Set(config.unlocks.rules(of: .title).map(\.id))
        for rule in config.unlocks.rules {
            guard let titleID = rule.reward.titleID else { continue }
            XCTAssertTrue(titleIDs.contains(titleID), "规则 \(rule.id) 引用了不存在的称号 \(titleID)")
        }
    }

    func testEveryUnlockMetricIsKnown() {
        let known: Set<String> = [
            MetricKey.totalQuestsCompleted, MetricKey.totalMainQuestsCompleted,
            MetricKey.totalSideQuestsCompleted, MetricKey.totalHabitCheckIns,
            MetricKey.playerLevel, MetricKey.maxSkillLevel, MetricKey.loginStreak,
            MetricKey.bestLoginStreak, MetricKey.totalFocusMinutes, MetricKey.totalStudyMinutes,
            MetricKey.totalEXPEarned, MetricKey.totalGoldEarned, MetricKey.totalDays,
            MetricKey.perfectDays, MetricKey.earliestCompletionHour, MetricKey.latestCompletionHour,
            MetricKey.achievementsUnlocked, MetricKey.challengesCompleted,
            MetricKey.skillLevel, MetricKey.habitStreak
        ]
        for rule in config.unlocks.rules {
            for condition in rule.conditions {
                XCTAssertTrue(known.contains(condition.metric), "规则 \(rule.id) 使用了未知指标 \(condition.metric)")
            }
        }
    }

    // MARK: - 商店

    func testShopItemIDsAreUnique() {
        let ids = config.shop.items.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    /// 默认主题必须存在且免费，否则新玩家开局就没有配色
    func testDefaultThemeIsFree() {
        let item = config.shop.item(id: "theme_default")
        XCTAssertNotNil(item)
        XCTAssertEqual(item?.price, 0)
        XCTAssertNotNil(item?.accentHex)
    }

    func testEveryThemeHasPalette() {
        for item in config.shop.items(of: .theme) {
            XCTAssertNotNil(item.accentHex, "主题 \(item.id) 缺少 accent 颜色")
        }
    }

    // MARK: - 属性与技能目录

    func testFortuneTiersAreSane() {
        let fortune = config.fortune
        XCTAssertGreaterThan(fortune.luckyGrowthChance, 0)
        XCTAssertLessThanOrEqual(fortune.luckyGrowthChance, 1)
        XCTAssertGreaterThan(fortune.luckyXPOnGrowth, 0)
        XCTAssertEqual(fortune.fortunes.count, 4)
        let weight = fortune.fortunes.reduce(0.0) { $0 + $1.weight }
        XCTAssertGreaterThan(weight, 0)
        for tier in fortune.fortunes {
            XCTAssertGreaterThanOrEqual(tier.xpBonus, 0)
            XCTAssertGreaterThanOrEqual(tier.goldBonus, 0)
        }
    }

    func testSkillCatalogAffinitiesSumToOne() {
        for preset in config.skillCatalog.skills {
            let total = preset.parsedAffinities.reduce(0.0) { $0 + $1.weight }
            XCTAssertEqual(total, 1.0, accuracy: 0.001, "技能 \(preset.id) 的属性亲和不是 100%")
            XCTAssertFalse(preset.categories.isEmpty, "技能 \(preset.id) 缺少类别")
            XCTAssertNil(preset.affinities["lucky"], "Lucky 不能出现在技能亲和里")
        }
    }

    func testSkillCatalogIDsAreUnique() {
        let ids = config.skillCatalog.skills.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }
}
