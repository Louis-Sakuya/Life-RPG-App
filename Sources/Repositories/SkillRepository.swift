import Foundation
import SwiftData

struct SkillRepository {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func allSkills(includeArchived: Bool = false) -> [Skill] {
        let descriptor = FetchDescriptor<Skill>(sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)])
        let skills = (try? context.fetch(descriptor)) ?? []
        return includeArchived ? skills : skills.filter { !$0.isArchived }
    }

    func skill(id: UUID) -> Skill? {
        let descriptor = FetchDescriptor<Skill>(predicate: #Predicate { $0.id == id })
        return (try? context.fetch(descriptor))?.first
    }

    func skill(named name: String) -> Skill? {
        let descriptor = FetchDescriptor<Skill>(predicate: #Predicate { $0.name == name })
        return (try? context.fetch(descriptor))?.first
    }

    /// 按 id 批量取回，用于把奖励一次性分发给多个技能
    func skills(ids: [UUID]) -> [UUID: Skill] {
        guard !ids.isEmpty else { return [:] }
        let set = Set(ids)
        return allSkills(includeArchived: true)
            .filter { set.contains($0.id) }
            .reduce(into: [:]) { $0[$1.id] = $1 }
    }

    @discardableResult
    func insert(_ skill: Skill) -> Skill {
        context.insert(skill)
        return skill
    }

    func delete(_ skill: Skill) {
        context.delete(skill)
    }
}
