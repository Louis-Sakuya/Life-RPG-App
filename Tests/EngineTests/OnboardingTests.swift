import XCTest
@testable import LifeRPG

@MainActor
final class OnboardingTests: XCTestCase {

    private func makeStore() -> GameStore {
        let store = GameStore(container: AppContainer(inMemory: true))
        store.bootstrap()
        return store
    }

    func testNewSaveNeedsOnboardingAndHasNoSeededSkills() {
        let store = makeStore()
        XCTAssertTrue(store.needsOnboarding)
        XCTAssertTrue(store.skills.isEmpty)
        XCTAssertTrue(store.habits.isEmpty)
        XCTAssertEqual(store.player.nickname, Player.defaultNickname)
        XCTAssertEqual(store.player.totalEXP, 0)
        XCTAssertEqual(store.player.lastActiveDayValue, 0)
    }

    func testExistingSaveSkipsOnboarding() {
        let container = AppContainer(inMemory: true)
        let player = PlayerRepository(context: container.context).currentPlayer()
        player.nickname = "老冒险者"
        player.totalEXP = 120
        let skill = Skill(name: "编程", iconName: "chevron.left.forwardslash.chevron.right")
        SkillRepository(context: container.context).insert(skill)
        container.save()

        let store = GameStore(container: container)
        store.bootstrap()
        XCTAssertFalse(store.needsOnboarding)
        XCTAssertEqual(store.player.nickname, "老冒险者")
        XCTAssertEqual(store.skills.count, 1)
    }

    func testCompleteOnboardingCreatesSkillsAndStartsTheDay() {
        let store = makeStore()
        let programming = store.container.config.skillCatalog.preset(id: "programming")
        XCTAssertNotNil(programming)

        store.completeOnboarding(
            nickname: " 晨星旅人 ",
            skills: [
                .fromPreset(programming!),
                OnboardingSkillDraft(
                    name: "折纸",
                    iconName: "star.fill",
                    colorHex: "#5B8DEF",
                    affinities: [StatAffinity(stat: .creation, weight: 1)]
                )
            ]
        )

        XCTAssertFalse(store.needsOnboarding)
        XCTAssertEqual(store.player.nickname, "晨星旅人")
        XCTAssertEqual(store.skills.count, 2)
        XCTAssertTrue(store.skills.contains { $0.catalogID == "programming" })
        XCTAssertTrue(store.skills.contains { $0.name == "折纸" })
        XCTAssertGreaterThan(store.player.lastActiveDayValue, 0)
        XCTAssertGreaterThanOrEqual(store.player.totalDaysPlayed, 1)
    }

    func testCompleteOnboardingSavesPresetAndCustomAvatars() {
        let store = makeStore()
        let photo = Data("custom-avatar".utf8)

        store.completeOnboarding(
            nickname: "旅人",
            avatarSymbol: "flame.fill",
            avatarImageData: photo,
            skills: []
        )

        XCTAssertEqual(store.player.avatarSymbol, "flame.fill")
        XCTAssertEqual(store.player.avatarImageData, photo)

        store.updateAvatar(symbol: "leaf.fill", imageData: nil)
        XCTAssertEqual(store.player.avatarSymbol, "leaf.fill")
        XCTAssertNil(store.player.avatarImageData)
    }

    func testCompleteOnboardingCapsSkillsAtFive() {
        let store = makeStore()
        let presets = Array(store.container.config.skillCatalog.skills.prefix(7))
        XCTAssertGreaterThanOrEqual(presets.count, 6)

        store.completeOnboarding(
            nickname: "旅人",
            skills: presets.map(OnboardingSkillDraft.fromPreset)
        )

        XCTAssertEqual(store.skills.count, OnboardingSkillDraft.maxCount)
        XCTAssertEqual(store.skillSlotCap, store.container.config.balance.initialSkillSlots)
        XCTAssertFalse(store.canLearnSkill)
    }

    func testSkillCapBlocksLearningUntilASlotIsClaimed() {
        let store = makeStore()
        let presets = Array(store.container.config.skillCatalog.skills.prefix(5))
        store.completeOnboarding(nickname: "旅人", skills: presets.map(OnboardingSkillDraft.fromPreset))
        XCTAssertFalse(store.canLearnSkill)
        XCTAssertFalse(store.createSkill(name: "折纸", iconName: "star.fill", colorHex: "#5B8DEF"))

        store.pendingLevelUpChoices = [LevelUpEvent(level: 2, goldReward: 0, requiresChoice: true)]
        store.player.unclaimedLevelUpChoices = 1
        store.claimLevelUpSkillSlot()

        XCTAssertEqual(store.skillSlotCap, 6)
        XCTAssertTrue(store.canLearnSkill)
        XCTAssertTrue(store.createSkill(name: "折纸", iconName: "star.fill", colorHex: "#5B8DEF"))
        XCTAssertFalse(store.canLearnSkill)
    }

    func testForgettingASkillFreesTheSlotAndErasesProgress() {
        let store = makeStore()
        let programming = store.container.config.skillCatalog.preset(id: "programming")!
        store.completeOnboarding(nickname: "旅人", skills: [.fromPreset(programming)])
        store.skills[0].totalEXP = 500
        XCTAssertEqual(store.learnedSkillCount, 1)

        store.deleteSkill(store.skills[0])
        XCTAssertTrue(store.skills.isEmpty)
        XCTAssertTrue(store.canLearnSkill)
        XCTAssertTrue(store.createSkill(from: programming))
        XCTAssertEqual(store.skills.first?.totalEXP, 0)
    }

    func testResetAccountWipesProgressAndReturnsToOnboarding() {
        let store = makeStore()
        store.completeOnboarding(
            nickname: "晨星旅人",
            skills: store.container.config.skillCatalog.preset(id: "reading").map { [.fromPreset($0)] } ?? []
        )
        store.createHabit(
            name: "喝水",
            iconName: "drop.fill",
            colorHex: "#3EC1B3",
            dailyTarget: 8,
            reminderHour: 9,
            reminderMinute: 0,
            skillShares: []
        )
        XCTAssertFalse(store.needsOnboarding)
        XCTAssertFalse(store.skills.isEmpty)
        XCTAssertFalse(store.habits.isEmpty)

        XCTAssertNoThrow(try store.resetAccount())

        XCTAssertTrue(store.needsOnboarding)
        XCTAssertEqual(store.player.nickname, Player.defaultNickname)
        XCTAssertEqual(store.player.avatarSymbol, Player.defaultAvatarSymbol)
        XCTAssertNil(store.player.avatarImageData)
        XCTAssertEqual(store.player.totalEXP, 0)
        XCTAssertTrue(store.skills.isEmpty)
        XCTAssertTrue(store.habits.isEmpty)
        XCTAssertEqual(store.player.lastActiveDayValue, 0)
    }

    func testPendingResetClearsSaveBeforeNextLaunch() {
        let container = AppContainer(inMemory: true)
        let store = GameStore(container: container)
        store.bootstrap()
        store.completeOnboarding(nickname: "旅人", skills: [])
        XCTAssertEqual(store.player.nickname, "旅人")

        UserDefaults.standard.set(true, forKey: ExportService.pendingResetDefaultsKey)
        ExportService.consumePendingResetIfNeeded(context: container.context, config: container.config)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: ExportService.pendingResetDefaultsKey))

        let player = PlayerRepository(context: container.context).currentPlayer()
        XCTAssertEqual(player.nickname, Player.defaultNickname)
        XCTAssertEqual(player.totalEXP, 0)
    }
}
