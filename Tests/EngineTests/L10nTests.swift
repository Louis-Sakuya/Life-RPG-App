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
}
