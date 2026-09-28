import Foundation
import SwiftData

enum PurchaseError: LocalizedError, Equatable {
    case alreadyOwned
    case levelTooLow(required: Int)
    case notEnoughGold(short: Int)
    case shieldAlreadyHeld

    var errorDescription: String? {
        switch self {
        case .alreadyOwned: return L10n.t("shop.already_owned")
        case .levelTooLow(let required): return L10n.format("shop.level_too_low", required)
        case .notEnoughGold(let short): return L10n.format("shop.not_enough_gold", short)
        case .shieldAlreadyHeld: return L10n.t("shop.shield_held")
        }
    }
}

/// 商店。装饰品仍不改数值；消耗品只提供日程暂停或连胜保护。
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

    /// 免费商品视为默认拥有，不需要走购买流程。消耗品可重复购买，不走拥有判定。
    func isOwned(_ item: ShopItem) -> Bool {
        if item.kind == .consumable { return false }
        return item.price == 0 || ownedIDs().contains(item.id)
    }

    func validate(_ item: ShopItem, player: Player, sandbox: Bool = false) -> PurchaseError? {
        if item.kind == .consumable, item.id == ShopItemID.streakShield, player.hasStreakShield {
            return .shieldAlreadyHeld
        }
        if isOwned(item) { return .alreadyOwned }
        if sandbox { return nil }
        let level = config.playerCurve.level(forTotalEXP: player.totalEXP)
        if level < item.requiredLevel { return .levelTooLow(required: item.requiredLevel) }
        if player.gold < item.price { return .notEnoughGold(short: item.price - player.gold) }
        return nil
    }

    @discardableResult
    func purchase(_ item: ShopItem, player: Player, sandbox: Bool = false) throws -> OwnedItem {
        if let error = validate(item, player: player, sandbox: sandbox) { throw error }
        let owned = item.kind == .consumable
            ? OwnedItem(itemID: item.id, kind: item.kind, pricePaid: sandbox ? 0 : item.price)
            : progression.recordPurchase(item: item)
        if item.kind == .consumable {
            context.insert(owned)
            grantConsumable(item, to: player)
        }
        // 沙盒购买不改真实余额，避免测试数据污染流水
        if !sandbox {
            // 走流水而不是直接扣金币，保证"我的金币去哪了"永远可追溯
            rewards.grantFlat(
                exp: 0,
                gold: -item.price,
                to: player,
                source: .purchase,
                sourceRuleID: item.id,
                title: L10n.format("shop.buy_title", item.localizedName),
                on: calendar.today
            )
        }
        if item.kind != .consumable {
            equip(item, player: player, force: true)
        }
        return owned
    }

    private func grantConsumable(_ item: ShopItem, to player: Player) {
        switch item.id {
        case ShopItemID.leaveWard:
            player.leaveCardCount += 1
        case ShopItemID.streakShield:
            player.hasStreakShield = true
        default:
            break
        }
    }

    func equip(_ item: ShopItem, player: Player, force: Bool = false) {
        guard isOwned(item) else { return }
        normalizeEquipment(player)
        switch item.kind {
        case .theme:
            player.currentThemeID = item.id
        case .background:
            toggle(&player.currentBackgroundID, item.id, force: force)
        case .avatarFrame:
            toggleOptional(&player.currentFrameID, item.id, force: force)
        case .pet:
            toggle(&player.currentPetID, item.id, force: force)
        case .sound:
            toggle(&player.currentSoundID, item.id, force: force)
        case .effect:
            if item.cueID == "levelUp" {
                toggle(&player.currentLevelEffectID, item.id, force: force)
            } else {
                toggle(&player.currentCompleteEffectID, item.id, force: force)
            }
        case .consumable:
            break
        }
    }

    func isEquipped(_ item: ShopItem, player: Player) -> Bool {
        switch item.kind {
        case .theme: return player.currentThemeID == item.id
        case .background: return player.currentBackgroundID == item.id
        case .avatarFrame: return player.currentFrameID == item.id
        case .pet: return player.currentPetID == item.id
        case .sound: return player.currentSoundID == item.id
        case .effect:
            if item.cueID == "levelUp" { return player.currentLevelEffectID == item.id }
            return player.currentCompleteEffectID == item.id
        case .consumable:
            return false
        }
    }

    func canUnequip(_ item: ShopItem) -> Bool {
        item.kind != .theme
    }

    func palette(for player: Player) -> ThemePalette {
        normalizeEquipment(player)
        return ThemePalette(item: config.shop.item(id: player.currentThemeID))
    }

    /// 旧版本把背景写进了主题槽。读档时拆开，避免极光把整套配色顶掉。
    func normalizeEquipment(_ player: Player) {
        if let item = config.shop.item(id: player.currentThemeID), item.kind != .theme {
            if item.kind == .background, player.currentBackgroundID.isEmpty {
                player.currentBackgroundID = item.id
            }
            player.currentThemeID = "theme_default"
        }
        clearIfUnowned(&player.currentBackgroundID, player: player)
        clearIfUnownedOptional(&player.currentFrameID, player: player)
        clearIfUnowned(&player.currentPetID, player: player)
        clearIfUnowned(&player.currentSoundID, player: player)
        clearIfUnowned(&player.currentLevelEffectID, player: player)
        clearIfUnowned(&player.currentCompleteEffectID, player: player)
    }

    private func toggle(_ slot: inout String, _ id: String, force: Bool) {
        if !force, slot == id {
            slot = ""
        } else {
            slot = id
        }
    }

    private func toggleOptional(_ slot: inout String?, _ id: String, force: Bool) {
        if !force, slot == id {
            slot = nil
        } else {
            slot = id
        }
    }

    private func clearIfUnowned(_ slot: inout String, player: Player) {
        guard !slot.isEmpty, let item = config.shop.item(id: slot), !isOwned(item) else { return }
        slot = ""
    }

    private func clearIfUnownedOptional(_ slot: inout String?, player: Player) {
        guard let id = slot, let item = config.shop.item(id: id), !isOwned(item) else { return }
        slot = nil
    }
}
