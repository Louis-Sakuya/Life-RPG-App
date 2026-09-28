import XCTest
@testable import LifeRPG

final class L10nTests: XCTestCase {

    override func setUp() {
        super.setUp()
        L10n.bootstrap(bundle: Bundle(for: L10nTests.self))
        L10n.language = .chinese
    }

    func testChineseAndEnglishTablesHaveTheSameKeys() {
        let zh = L10n.table(for: "zh-Hans")
        let en = L10n.table(for: "en")
        XCTAssertFalse(zh.isEmpty)
        XCTAssertEqual(Set(zh.keys), Set(en.keys), "中英文语言表的 key 必须一致，否则切换语言会出现漏翻")
    }

    func testChromeStringsSwitchWithLanguage() {
        L10n.language = .chinese
        XCTAssertEqual(L10n.t("tab.today"), "今日")
        XCTAssertEqual(L10n.t("settings.language"), "语言")
        L10n.language = .english
        XCTAssertEqual(L10n.t("tab.today"), "Today")
        XCTAssertEqual(L10n.t("settings.language"), "Language")
    }

    func testFormatFollowsLanguage() {
        L10n.language = .chinese
        XCTAssertEqual(L10n.format("date.md", 8, 20), "8月20日")
        L10n.language = .english
        XCTAssertEqual(L10n.format("date.md", 8, 20), "8/20")
    }

    func testCoreStatTitleFollowsLanguage() {
        L10n.language = .chinese
        XCTAssertEqual(CoreStatID.body.title, "身体力")
        L10n.language = .english
        XCTAssertEqual(CoreStatID.body.title, "Body")
    }

    func testSkillLevelUpBannerUsesLocalizedCatalogName() {
        let event = LevelUpEvent(skillName: "Running", catalogID: "running", level: 3, goldReward: 0)
        L10n.language = .chinese
        XCTAssertEqual(event.localizedSubjectName, "跑步")
        L10n.language = .english
        XCTAssertEqual(event.localizedSubjectName, "Running")
    }

    func testCustomSkillLevelUpKeepsPlayerName() {
        let event = LevelUpEvent(skillName: "我的技能", catalogID: nil, level: 2, goldReward: 0)
        L10n.language = .english
        XCTAssertEqual(event.localizedSubjectName, "我的技能")
    }

    func testStatLevelUpBannerFollowsLanguage() {
        let event = LevelUpEvent(skillName: "Body", statID: .body, level: 4, goldReward: 0)
        L10n.language = .chinese
        XCTAssertEqual(event.localizedSubjectName, "身体力")
        L10n.language = .english
        XCTAssertEqual(event.localizedSubjectName, "Body")
    }

    func testMissingKeyFallsBackToChineseThenKey() {
        L10n.language = .english
        XCTAssertEqual(L10n.t("this.key.does.not.exist"), "this.key.does.not.exist")
    }

    func testEveryUnlockRuleHasLocalizedNameAndDetail() {
        let config = GameConfig.load(bundle: Bundle(for: L10nTests.self))
        let zh = L10n.table(for: "zh-Hans")
        let en = L10n.table(for: "en")
        for rule in config.unlocks.rules {
            let nameKey = "unlock.\(rule.id).name"
            let detailKey = "unlock.\(rule.id).detail"
            XCTAssertNotNil(zh[nameKey], "zh 缺少 \(nameKey)")
            XCTAssertNotNil(en[nameKey], "en 缺少 \(nameKey)")
            XCTAssertNotNil(zh[detailKey], "zh 缺少 \(detailKey)")
            XCTAssertNotNil(en[detailKey], "en 缺少 \(detailKey)")
            XCTAssertNotEqual(zh[nameKey], en[nameKey], "\(rule.id) 中英文名称相同，可能未本地化")
        }
    }

    func testExistingTitlesUseChineseNames() {
        L10n.language = .chinese
        XCTAssertEqual(L10n.t("unlock.title_programmer.name"), "代码行者")
        XCTAssertEqual(L10n.t("unlock.title_legend.name"), "传说")
        XCTAssertEqual(L10n.t("unlock.title_novice.name"), "初心者")
        L10n.language = .english
        XCTAssertEqual(L10n.t("unlock.title_programmer.name"), "Code Walker")
        XCTAssertEqual(L10n.t("unlock.title_legend.name"), "Legend")
        XCTAssertEqual(L10n.t("unlock.title_novice.name"), "Novice")
    }
}
