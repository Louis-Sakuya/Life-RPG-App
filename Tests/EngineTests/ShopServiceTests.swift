import XCTest
@testable import LifeRPG

@MainActor
final class ShopServiceTests: XCTestCase {

    private func make() -> (container: AppContainer, player: Player, shop: ShopService) {
        let container = AppContainer(inMemory: true)
        container.bootstrap()
        let player = PlayerRepository(context: container.context).currentPlayer()
        return (container, player, container.shop)
    }

    private func gatedItem() -> ShopItem {
        ShopItem(
            id: "theme_sandbox_gate",
            kind: .theme,
            name: "沙盒主题",
            price: 9_999,
            requiredLevel: 50,
            payload: ["accent": "#5B8DEF"]
        )
    }

    func testPurchaseFailsWhenLevelTooLow() {
        let (_, player, shop) = make()
        player.gold = 99_999
        XCTAssertEqual(shop.validate(gatedItem(), player: player), .levelTooLow(required: 50))
    }

    func testPurchaseFailsWhenGoldIsShort() {
        let (_, player, shop) = make()
        player.gold = 10
        let item = ShopItem(id: "theme_cheap_gate", kind: .theme, name: "入门主题", price: 200, requiredLevel: 1)
        XCTAssertEqual(shop.validate(item, player: player), .notEnoughGold(short: 190))
    }

    func testSandboxIgnoresLevelAndGoldAndDoesNotSpend() throws {
        let (_, player, shop) = make()
        player.gold = 12
        let item = gatedItem()

        XCTAssertNil(shop.validate(item, player: player, sandbox: true))
        try shop.purchase(item, player: player, sandbox: true)

        XCTAssertEqual(player.gold, 12)
        XCTAssertTrue(shop.isOwned(item))
    }

    func testNormalPurchaseDeductsGold() throws {
        let (_, player, shop) = make()
        player.gold = 300
        let item = ShopItem(id: "theme_paid", kind: .theme, name: "付费主题", price: 200, requiredLevel: 1)

        try shop.purchase(item, player: player)

        XCTAssertEqual(player.gold, 100)
        XCTAssertTrue(shop.isOwned(item))
    }

    func testStoreSandboxToggleUnlocksShopWithoutSpending() {
        let store = GameStore(container: AppContainer(inMemory: true))
        store.bootstrap()
        store.player.gold = 3

        let item = gatedItem()
        XCTAssertEqual(store.purchase(item), .levelTooLow(required: 50))
        XCTAssertFalse(store.container.shop.isOwned(item))

        store.setTestShopSandbox(true)
        XCTAssertTrue(store.isTestShopSandboxEnabled)
        XCTAssertNil(store.purchase(item))
        XCTAssertEqual(store.player.gold, 3)
        XCTAssertTrue(store.container.shop.isOwned(item))
    }
}
