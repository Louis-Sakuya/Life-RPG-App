import Foundation
import SwiftData

/// 全部持久化实体的清单。新增实体时只需要在这里登记一次。
enum ModelSchemaRegistry {
    static let allModels: [any PersistentModel.Type] = [
        Player.self,
        Quest.self,
        QuestSkillLink.self,
        QuestTemplate.self,
        Skill.self,
        Habit.self,
        HabitLog.self,
        Challenge.self,
        UnlockRecord.self,
        DailyRecord.self,
        RewardTransaction.self,
        Reminder.self,
        OwnedItem.self,
        FailedQuestRecord.self,
        AppSettings.self
    ]

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(allModels)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
