import Foundation
import SwiftData

/// 商店购买记录。商品定义在 `shop_items.json`，数据库只记录拥有关系与售价快照。
@Model
final class OwnedItem {
    var id: UUID = UUID()
    var itemID: String = ""
    var kindRaw: String = ShopItemKind.theme.rawValue
    var purchasedAt: Date = Date()
    /// 购买时的售价，改价不影响历史流水的可读性
    var pricePaid: Int = 0

    init(itemID: String, kind: ShopItemKind, pricePaid: Int) {
        self.id = UUID()
        self.itemID = itemID
        self.kindRaw = kind.rawValue
        self.pricePaid = pricePaid
        self.purchasedAt = Date()
    }

    var kind: ShopItemKind {
        get { ShopItemKind(rawValue: kindRaw) ?? .theme }
        set { kindRaw = newValue.rawValue }
    }
}
