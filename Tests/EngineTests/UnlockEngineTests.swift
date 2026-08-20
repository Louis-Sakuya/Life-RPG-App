import XCTest
@testable import LifeRPG

final class UnlockEngineTests: XCTestCase {

    private func snapshot(
        scalars: [String: Double] = [:],
        skills: [String: Double] = [:],
        habits: [String: Double] = [:]
    ) -> MetricsSnapshot {
        MetricsSnapshot(scalars: scalars, skillLevels: skills, habitStreaks: habits)
    }

    private func rule(
        id: String = "r1",
        kind: UnlockKind = .achievement,
        conditions: [UnlockCondition],
        reward: RewardBundle = RewardBundle()
    ) -> UnlockRule {
        UnlockRule(id: id, kind: kind, name: id, conditions: conditions, reward: reward)
    }

    // MARK: - 条件求值

    func testGreaterOrEqualCondition() {
        let condition = UnlockCondition(metric: MetricKey.totalQuestsCompleted, comparator: .gte, threshold: 100)
        XCTAssertFalse(UnlockEngine.isSatisfied(condition, snapshot: snapshot(scalars: [MetricKey.totalQuestsCompleted: 99])))
        XCTAssertTrue(UnlockEngine.isSatisfied(condition, snapshot: snapshot(scalars: [MetricKey.totalQuestsCompleted: 100])))
    }

    func testLessOrEqualCondition() {
        // "早上 6 点前完成任务"用 lte 描述，未记录时的哨兵值 99 必须判为未满足
        let condition = UnlockCondition(metric: MetricKey.earliestCompletionHour, comparator: .lte, threshold: 6)
        XCTAssertFalse(UnlockEngine.isSatisfied(condition, snapshot: snapshot(scalars: [MetricKey.earliestCompletionHour: 99])))
        XCTAssertTrue(UnlockEngine.isSatisfied(condition, snapshot: snapshot(scalars: [MetricKey.earliestCompletionHour: 5])))
    }

    func testMissingMetricIsNeverSatisfied() {
        let condition = UnlockCondition(metric: "nonexistent", comparator: .gte, threshold: 0)
        XCTAssertFalse(UnlockEngine.isSatisfied(condition, snapshot: snapshot()))
    }

    func testConditionsAreAnded() {
        let subject = rule(conditions: [
            UnlockCondition(metric: MetricKey.playerLevel, comparator: .gte, threshold: 10),
            UnlockCondition(metric: MetricKey.totalQuestsCompleted, comparator: .gte, threshold: 50)
        ])
        XCTAssertFalse(UnlockEngine.isSatisfied(subject, snapshot: snapshot(scalars: [
            MetricKey.playerLevel: 10,
            MetricKey.totalQuestsCompleted: 49
        ])))
        XCTAssertTrue(UnlockEngine.isSatisfied(subject, snapshot: snapshot(scalars: [
            MetricKey.playerLevel: 10,
            MetricKey.totalQuestsCompleted: 50
        ])))
    }

    func testRuleWithoutConditionsNeverUnlocks() {
        XCTAssertFalse(UnlockEngine.isSatisfied(rule(conditions: []), snapshot: snapshot()))
    }

    // MARK: - 参数化指标

    func testSkillLevelUsesParam() {
        let subject = rule(conditions: [
            UnlockCondition(metric: MetricKey.skillLevel, param: "Programming", comparator: .gte, threshold: 20)
        ])
        XCTAssertTrue(UnlockEngine.isSatisfied(subject, snapshot: snapshot(skills: ["Programming": 20, "Fitness": 1])))
        XCTAssertFalse(UnlockEngine.isSatisfied(subject, snapshot: snapshot(skills: ["Fitness": 99])))
    }

    func testSkillLevelWithoutParamFallsBackToMax() {
        let subject = rule(conditions: [
            UnlockCondition(metric: MetricKey.skillLevel, comparator: .gte, threshold: 30)
        ])
        XCTAssertTrue(UnlockEngine.isSatisfied(subject, snapshot: snapshot(skills: ["A": 5, "B": 40])))
    }

    func testHabitStreakUsesParam() {
        let subject = rule(conditions: [
            UnlockCondition(metric: MetricKey.habitStreak, param: "阅读", comparator: .gte, threshold: 100)
        ])
        XCTAssertTrue(UnlockEngine.isSatisfied(subject, snapshot: snapshot(habits: ["阅读": 100])))
        XCTAssertFalse(UnlockEngine.isSatisfied(subject, snapshot: snapshot(habits: ["阅读": 99])))
    }

    // MARK: - 批量评估

    func testAlreadyUnlockedRulesAreExcluded() {
        let rules = [
            rule(id: "a", conditions: [UnlockCondition(metric: MetricKey.playerLevel, comparator: .gte, threshold: 1)]),
            rule(id: "b", conditions: [UnlockCondition(metric: MetricKey.playerLevel, comparator: .gte, threshold: 1)])
        ]
        let result = UnlockEngine.evaluate(
            snapshot: snapshot(scalars: [MetricKey.playerLevel: 5]),
            rules: rules,
            unlockedIDs: ["a"]
        )
        XCTAssertEqual(result.map(\.id), ["b"])
    }

    // MARK: - 进度

    func testProgressIsClampedToUnitRange() {
        let subject = rule(conditions: [
            UnlockCondition(metric: MetricKey.totalQuestsCompleted, comparator: .gte, threshold: 100)
        ])
        XCTAssertEqual(UnlockEngine.progress(of: subject, snapshot: snapshot(scalars: [MetricKey.totalQuestsCompleted: 0])), 0, accuracy: 0.001)
        XCTAssertEqual(UnlockEngine.progress(of: subject, snapshot: snapshot(scalars: [MetricKey.totalQuestsCompleted: 37])), 0.37, accuracy: 0.001)
        XCTAssertEqual(UnlockEngine.progress(of: subject, snapshot: snapshot(scalars: [MetricKey.totalQuestsCompleted: 500])), 1, accuracy: 0.001)
    }

    /// 多条件规则的进度取最慢的一条，否则进度条会在还差很远时显示接近完成
    func testProgressTakesSlowestCondition() {
        let subject = rule(conditions: [
            UnlockCondition(metric: MetricKey.playerLevel, comparator: .gte, threshold: 10),
            UnlockCondition(metric: MetricKey.totalQuestsCompleted, comparator: .gte, threshold: 100)
        ])
        let value = UnlockEngine.progress(of: subject, snapshot: snapshot(scalars: [
            MetricKey.playerLevel: 9,
            MetricKey.totalQuestsCompleted: 10
        ]))
        XCTAssertEqual(value, 0.1, accuracy: 0.001)
    }

    func testProgressTextShowsCurrentOverThreshold() {
        let subject = rule(conditions: [
            UnlockCondition(metric: MetricKey.totalQuestsCompleted, comparator: .gte, threshold: 100)
        ])
        XCTAssertEqual(
            UnlockEngine.progressText(of: subject, snapshot: snapshot(scalars: [MetricKey.totalQuestsCompleted: 37])),
            "37 / 100"
        )
    }

    // MARK: - 配置解码

    /// `reward: {}` 必须能解码。Swift 合成的 Decodable 不会对缺失键使用属性默认值，
    /// 所以这些配置结构都写了自定义解码。
    func testRuleDecodesWithEmptyReward() throws {
        let json = """
        {
          "id": "title_x",
          "kind": "title",
          "name": "X",
          "conditions": [{ "metric": "playerLevel", "comparator": "gte", "threshold": 5 }],
          "reward": {}
        }
        """
        let decoded = try JSONDecoder().decode(UnlockRule.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.kind, .title)
        XCTAssertTrue(decoded.reward.isEmpty)
        XCTAssertEqual(decoded.icon, "star.fill")
    }

    func testRuleDecodesWithoutOptionalKeys() throws {
        let json = """
        { "id": "a", "kind": "achievement", "name": "A" }
        """
        let decoded = try JSONDecoder().decode(UnlockRule.self, from: Data(json.utf8))
        XCTAssertTrue(decoded.conditions.isEmpty)
        XCTAssertEqual(decoded.detail, "")
    }
}
