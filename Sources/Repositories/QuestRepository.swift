import Foundation
import SwiftData

struct QuestRepository {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - 查询

    func quests(on day: GameDay) -> [Quest] {
        let value = day.value
        let descriptor = FetchDescriptor<Quest>(
            predicate: #Predicate { $0.scheduledDayValue == value && $0.statusRaw != "cancelled" },
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]
        )
        let fetched = (try? context.fetch(descriptor)) ?? []
        return fetched.sorted(by: Quest.boardOrder)
    }

    func questsCompleted(on day: GameDay) -> [Quest] {
        let value = day.value
        let descriptor = FetchDescriptor<Quest>(
            predicate: #Predicate { $0.completedDayValue == value && $0.statusRaw == "completed" }
        )
        return ((try? context.fetch(descriptor)) ?? []).sorted(by: Quest.boardOrder)
    }

    func quests(in range: ClosedRange<GameDay>) -> [Quest] {
        let lower = range.lowerBound.value
        let upper = range.upperBound.value
        let descriptor = FetchDescriptor<Quest>(
            predicate: #Predicate { $0.scheduledDayValue >= lower && $0.scheduledDayValue <= upper },
            sortBy: [SortDescriptor(\.scheduledDayValue), SortDescriptor(\.sortOrder)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// 计划日早于给定日且仍未完成的任务，用于每日结算时标记延期
    func unfinishedQuests(before day: GameDay) -> [Quest] {
        let value = day.value
        let descriptor = FetchDescriptor<Quest>(
            predicate: #Predicate { $0.scheduledDayValue < value && $0.statusRaw == "pending" },
            sortBy: [SortDescriptor(\.scheduledDayValue)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func upcomingQuests(after day: GameDay, limit: Int = 200) -> [Quest] {
        let value = day.value
        var descriptor = FetchDescriptor<Quest>(
            predicate: #Predicate { $0.scheduledDayValue > value && $0.statusRaw == "pending" },
            sortBy: [SortDescriptor(\.scheduledDayValue), SortDescriptor(\.sortOrder)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    func quest(id: UUID) -> Quest? {
        let descriptor = FetchDescriptor<Quest>(predicate: #Predicate { $0.id == id })
        return (try? context.fetch(descriptor))?.first
    }

    func allQuests() -> [Quest] {
        let descriptor = FetchDescriptor<Quest>(sortBy: [SortDescriptor(\.scheduledDayValue)])
        return (try? context.fetch(descriptor)) ?? []
    }

    /// 某模板在指定日是否已经生成过实例，保证补算的幂等性
    func hasGeneratedQuest(templateID: UUID, on day: GameDay) -> Bool {
        let value = day.value
        // 谓词里比较的是可选属性，局部变量必须显式声明为可选，否则宏展开时类型不匹配
        let target: UUID? = templateID
        let descriptor = FetchDescriptor<Quest>(
            predicate: #Predicate { $0.templateID == target && $0.scheduledDayValue == value }
        )
        return ((try? context.fetch(descriptor))?.isEmpty == false)
    }

    // MARK: - 写入

    @discardableResult
    func insert(_ quest: Quest, skillShares: [SkillShare] = []) -> Quest {
        context.insert(quest)
        applySkillShares(skillShares, to: quest)
        return quest
    }

    func applySkillShares(_ shares: [SkillShare], to quest: Quest) {
        for link in quest.skillLinks ?? [] {
            context.delete(link)
        }
        quest.skillLinks = []
        for share in shares where share.expShare > 0 {
            let link = QuestSkillLink(skillID: share.skillID, expShare: share.expShare)
            link.quest = quest
            context.insert(link)
            quest.skillLinks?.append(link)
        }
    }

    func skillShares(of quest: Quest) -> [SkillShare] {
        (quest.skillLinks ?? []).map { SkillShare(skillID: $0.skillID, expShare: $0.expShare) }
    }

    func delete(_ quest: Quest) {
        context.delete(quest)
    }

    func detachSkill(_ skillID: UUID) {
        let descriptor = FetchDescriptor<QuestSkillLink>(predicate: #Predicate { $0.skillID == skillID })
        for link in (try? context.fetch(descriptor)) ?? [] {
            context.delete(link)
        }
        for template in allTemplates() {
            template.skillShares = template.skillShares.filter { $0.skillID != skillID }
        }
    }

    // MARK: - 重复模板

    func activeTemplates() -> [QuestTemplate] {
        let descriptor = FetchDescriptor<QuestTemplate>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func allTemplates() -> [QuestTemplate] {
        let descriptor = FetchDescriptor<QuestTemplate>(sortBy: [SortDescriptor(\.createdAt)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func template(id: UUID) -> QuestTemplate? {
        let descriptor = FetchDescriptor<QuestTemplate>(predicate: #Predicate { $0.id == id })
        return (try? context.fetch(descriptor))?.first
    }

    @discardableResult
    func insert(_ template: QuestTemplate) -> QuestTemplate {
        context.insert(template)
        return template
    }

    func delete(_ template: QuestTemplate) {
        context.delete(template)
    }
}
