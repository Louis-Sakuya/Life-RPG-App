import Foundation
import SwiftData

/// 首次启动的数据播种。空白的 RPG 没有代入感，因此预置一套可直接上手的技能与习惯，
/// 用户随时可以删掉或改名。
@MainActor
struct SeedService {
    private let context: ModelContext
    private let config: GameConfig
    private let calendar: GameCalendar

    init(context: ModelContext, config: GameConfig, calendar: GameCalendar) {
        self.context = context
        self.config = config
        self.calendar = calendar
    }

    private static let defaultSkills: [(String, String, String)] = [
        ("Programming", "chevron.left.forwardslash.chevron.right", "#5B8DEF"),
        ("English", "character.book.closed.fill", "#E2603B"),
        ("Fitness", "figure.run", "#2FA36B"),
        ("Reading", "book.fill", "#C9A227"),
        ("Game Design", "gamecontroller.fill", "#9A6BFF")
    ]

    private static let defaultHabits: [(String, String, String, Int)] = [
        ("阅读", "book.fill", "#C9A227", 1),
        ("健身", "figure.strengthtraining.traditional", "#2FA36B", 1),
        ("喝水", "drop.fill", "#3EC1B3", 8),
        ("冥想", "leaf.fill", "#9A6BFF", 1)
    ]

    func bootstrap() {
        let players = PlayerRepository(context: context)
        _ = players.currentPlayer()
        _ = players.settings()

        seedSkillsIfNeeded()
        seedHabitsIfNeeded()
        syncBuiltInChallenges()
    }

    private func seedSkillsIfNeeded() {
        let repository = SkillRepository(context: context)
        guard repository.allSkills(includeArchived: true).isEmpty else { return }
        for (index, entry) in Self.defaultSkills.enumerated() {
            repository.insert(Skill(name: entry.0, iconName: entry.1, colorHex: entry.2, sortOrder: index))
        }
    }

    private func seedHabitsIfNeeded() {
        let repository = HabitRepository(context: context)
        guard repository.allHabits(includeArchived: true).isEmpty else { return }
        for (index, entry) in Self.defaultHabits.enumerated() {
            repository.insert(
                Habit(name: entry.0, iconName: entry.1, colorHex: entry.2, dailyTarget: entry.3, sortOrder: index)
            )
        }
    }

    /// 内置挑战每次启动都对账一次，这样在 `unlock_rules.json` 里新增挑战后，
    /// 老用户升级应用也能拿到，而不需要写迁移代码。
    private func syncBuiltInChallenges() {
        let repository = ProgressionRepository(context: context)
        for rule in config.unlocks.rules(of: .challenge) {
            guard repository.challenge(ruleID: rule.id) == nil else { continue }
            guard let challenge = Challenge.fromRule(rule) else { continue }
            repository.insert(challenge)
        }
    }
}
