import Foundation

/// 统计量的键。成就、称号、挑战三套系统全部通过这些键去 `MetricsSnapshot` 取值，
/// 因此新增一条解锁规则不需要写任何代码。
enum MetricKey {
    static let totalQuestsCompleted = "totalQuestsCompleted"
    static let totalMainQuestsCompleted = "totalMainQuestsCompleted"
    static let totalSideQuestsCompleted = "totalSideQuestsCompleted"
    static let totalHabitCheckIns = "totalHabitCheckIns"
    static let playerLevel = "playerLevel"
    static let maxSkillLevel = "maxSkillLevel"
    static let loginStreak = "loginStreak"
    static let bestLoginStreak = "bestLoginStreak"
    static let totalFocusMinutes = "totalFocusMinutes"
    static let totalStudyMinutes = "totalStudyMinutes"
    static let totalEXPEarned = "totalEXPEarned"
    static let totalGoldEarned = "totalGoldEarned"
    static let totalDays = "totalDays"
    static let perfectDays = "perfectDays"
    static let earliestCompletionHour = "earliestCompletionHour"
    static let latestCompletionHour = "latestCompletionHour"
    static let achievementsUnlocked = "achievementsUnlocked"
    static let challengesCompleted = "challengesCompleted"

    /// 需要 `param` 指定技能名
    static let skillLevel = "skillLevel"
    /// 需要 `param` 指定习惯名
    static let habitStreak = "habitStreak"
}

enum MetricComparator: String, Codable, Sendable {
    case gte
    case lte
    case eq

    func matches(_ lhs: Double, _ rhs: Double) -> Bool {
        switch self {
        case .gte: return lhs >= rhs
        case .lte: return lhs <= rhs
        case .eq: return abs(lhs - rhs) < 0.000_001
        }
    }
}

enum UnlockKind: String, Codable, CaseIterable, Sendable {
    case achievement
    case title
    case challenge
}

struct UnlockCondition: Codable, Hashable, Sendable {
    var metric: String
    var param: String?
    var comparator: MetricComparator
    var threshold: Double

    init(metric: String, param: String? = nil, comparator: MetricComparator, threshold: Double) {
        self.metric = metric
        self.param = param
        self.comparator = comparator
        self.threshold = threshold
    }
}

/// 解锁奖励。JSON 里可以写成 `{}`，因此必须自定义解码，
/// Swift 合成的 Decodable 不会对缺失的键使用属性默认值。
struct RewardBundle: Codable, Hashable, Sendable {
    var exp: Int
    var gold: Int
    var titleID: String?
    var frameID: String?
    var themeID: String?

    init(exp: Int = 0, gold: Int = 0, titleID: String? = nil, frameID: String? = nil, themeID: String? = nil) {
        self.exp = exp
        self.gold = gold
        self.titleID = titleID
        self.frameID = frameID
        self.themeID = themeID
    }

    private enum CodingKeys: String, CodingKey {
        case exp, gold, titleID, frameID, themeID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        exp = try container.decodeIfPresent(Int.self, forKey: .exp) ?? 0
        gold = try container.decodeIfPresent(Int.self, forKey: .gold) ?? 0
        titleID = try container.decodeIfPresent(String.self, forKey: .titleID)
        frameID = try container.decodeIfPresent(String.self, forKey: .frameID)
        themeID = try container.decodeIfPresent(String.self, forKey: .themeID)
    }

    var isEmpty: Bool {
        exp == 0 && gold == 0 && titleID == nil && frameID == nil && themeID == nil
    }
}

/// 一条解锁规则。成就 / 称号 / 挑战共用同一套结构，区别只在 `kind`。
struct UnlockRule: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var kind: UnlockKind
    var name: String
    var detail: String
    var icon: String
    /// 多个条件之间是 AND 关系
    var conditions: [UnlockCondition]
    var reward: RewardBundle

    init(
        id: String,
        kind: UnlockKind,
        name: String,
        detail: String = "",
        icon: String = "star.fill",
        conditions: [UnlockCondition] = [],
        reward: RewardBundle = RewardBundle()
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.detail = detail
        self.icon = icon
        self.conditions = conditions
        self.reward = reward
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, name, detail, icon, conditions, reward
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        kind = try container.decode(UnlockKind.self, forKey: .kind)
        name = try container.decode(String.self, forKey: .name)
        detail = try container.decodeIfPresent(String.self, forKey: .detail) ?? ""
        icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? "star.fill"
        conditions = try container.decodeIfPresent([UnlockCondition].self, forKey: .conditions) ?? []
        reward = try container.decodeIfPresent(RewardBundle.self, forKey: .reward) ?? RewardBundle()
    }
}

struct UnlockCatalog: Codable, Sendable {
    var version: Int
    var rules: [UnlockRule]

    func rules(of kind: UnlockKind) -> [UnlockRule] {
        rules.filter { $0.kind == kind }
    }

    func rule(id: String) -> UnlockRule? {
        rules.first { $0.id == id }
    }

    static let empty = UnlockCatalog(version: 0, rules: [])
}
