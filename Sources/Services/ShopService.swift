import Foundation
import SwiftData

enum PurchaseError: LocalizedError {
    case alreadyOwned
    case levelTooLow(required: Int)
    case notEnoughGold(short: Int)

    var errorDescription: String? {
        switch self {
        case .alreadyOwned: return "已经拥有这件物品"
        case .levelTooLow(let required): return "需要达到 Lv\(required)"
        case .notEnoughGold(let short): return "还差 \(short) 金币"
        }
    }
}

/// 商店。所有商品都是纯装饰，不携带任何影响数值的字段，
/// 这样金币经济无论怎么膨胀都不会绕过任务奖励的平衡。
@MainActor
final class ShopService {
    private let context: ModelContext
    private let config: GameConfig
    private let calendar: GameCalendar
    private let progression: ProgressionRepository
    private let rewards: RewardService

    init(context: ModelContext, config: GameConfig, calendar: GameCalendar, rewards: RewardService) {
        self.context = context
        self.config = config
        self.calendar = calendar
        self.progression = ProgressionRepository(context: context)
        self.rewards = rewards
    }

    var catalog: ShopCatalog { config.shop }

    func ownedIDs() -> Set<String> {
        progression.ownedItemIDs()
    }

    /// 免费商品视为默认拥有，不需要走购买流程
    func isOwned(_ item: ShopItem) -> Bool {
        item.price == 0 || ownedIDs().contains(item.id)
    }

    func validate(_ item: ShopItem, player: Player) -> PurchaseError? {
        if isOwned(item) { return .alreadyOwned }
        let level = config.playerCurve.level(forTotalEXP: player.totalEXP)
        if level < item.requiredLevel { return .levelTooLow(required: item.requiredLevel) }
        if player.gold < item.price { return .notEnoughGold(short: item.price - player.gold) }
        return nil
    }

    @discardableResult
    func purchase(_ item: ShopItem, player: Player) throws -> OwnedItem {
        if let error = validate(item, player: player) { throw error }
        let owned = progression.recordPurchase(item: item)
        // 走流水而不是直接扣金币，保证"我的金币去哪了"永远可追溯
        rewards.grantFlat(
            exp: 0,
            gold: -item.price,
            to: player,
            source: .purchase,
            sourceRuleID: item.id,
            title: "购买 \(item.name)",
            on: calendar.today
        )
        return owned
    }

    func equip(_ item: ShopItem, player: Player) {
        guard isOwned(item) else { return }
        switch item.kind {
        case .theme, .background:
            player.currentThemeID = item.id
        case .avatarFrame:
            player.currentFrameID = item.id
        case .effect, .sound, .pet:
            // 这些品类目前只影响表现层，拥有即生效，不需要独立的装备槽
            break
        }
    }

    func isEquipped(_ item: ShopItem, player: Player) -> Bool {
        switch item.kind {
        case .theme, .background: return player.currentThemeID == item.id
        case .avatarFrame: return player.currentFrameID == item.id
        default: return isOwned(item)
        }
    }

    func palette(for player: Player) -> ThemePalette {
        ThemePalette(item: config.shop.item(id: player.currentThemeID))
    }
}
