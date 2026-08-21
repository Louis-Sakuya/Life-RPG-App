import Foundation

/// 启动时一次性加载的只读配置快照。任何数值改动都发生在 `Resources/Config/*.json`，
/// 逻辑代码不需要重新编译。加载失败时回退到内置默认值，保证应用永远能启动。
final class GameConfig: @unchecked Sendable {
    let balance: BalanceConfig
    let modifiers: ModifierConfig
    let unlocks: UnlockCatalog
    let shop: ShopCatalog
    let fortune: FortuneConfig
    let skillCatalog: SkillCatalog

    /// 加载过程中出现的问题，展示在设置页的诊断区域，便于发现 JSON 写错
    let loadIssues: [String]

    init(
        balance: BalanceConfig,
        modifiers: ModifierConfig,
        unlocks: UnlockCatalog,
        shop: ShopCatalog,
        fortune: FortuneConfig,
        skillCatalog: SkillCatalog,
        loadIssues: [String] = []
    ) {
        self.balance = balance
        self.modifiers = modifiers
        self.unlocks = unlocks
        self.shop = shop
        self.fortune = fortune
        self.skillCatalog = skillCatalog
        self.loadIssues = loadIssues
    }

    static let shared: GameConfig = GameConfig.load()

    static func load(bundle: Bundle = .main) -> GameConfig {
        var issues: [String] = []

        let balance: BalanceConfig = decode("balance", bundle: bundle, fallback: .fallback, issues: &issues)
        let modifiers: ModifierConfig = decode("modifiers", bundle: bundle, fallback: .fallback, issues: &issues)
        let unlocks: UnlockCatalog = decode("unlock_rules", bundle: bundle, fallback: .empty, issues: &issues)
        let shop: ShopCatalog = decode("shop_items", bundle: bundle, fallback: .fallback, issues: &issues)
        let fortune: FortuneConfig = decode("fortune", bundle: bundle, fallback: .fallback, issues: &issues)
        let skillCatalog: SkillCatalog = decode("skill_catalog", bundle: bundle, fallback: .fallback, issues: &issues)

        return GameConfig(
            balance: balance,
            modifiers: modifiers,
            unlocks: unlocks,
            shop: shop,
            fortune: fortune,
            skillCatalog: skillCatalog,
            loadIssues: issues
        )
    }

    // MARK: - 便利查询

    lazy var playerCurve = LevelCurve(config: balance.playerCurve)
    lazy var skillCurve = LevelCurve(config: balance.skillCurve)
    lazy var statCurve = LevelCurve(config: balance.statCurve)

    func modifier(_ id: String) -> RewardModifier? {
        modifiers.modifier(id: id)
    }

    // MARK: - 私有

    /// XcodeGen 用文件夹引用的方式打包 `Resources`，实际路径取决于构建配置，
    /// 因此按候选目录逐个尝试而不是硬编码一条路径。
    private static let searchDirectories: [String?] = [nil, "Config", "Resources/Config", "Resources"]

    private static func decode<T: Decodable>(
        _ name: String,
        bundle: Bundle,
        fallback: T,
        issues: inout [String]
    ) -> T {
        guard let url = locate(name, bundle: bundle) else {
            issues.append(L10n.format("config.missing", name))
            return fallback
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            issues.append(L10n.format("config.parse", name, error.localizedDescription))
            return fallback
        }
    }

    private static func locate(_ name: String, bundle: Bundle) -> URL? {
        for directory in searchDirectories {
            if let url = bundle.url(forResource: name, withExtension: "json", subdirectory: directory) {
                return url
            }
        }
        return nil
    }
}
