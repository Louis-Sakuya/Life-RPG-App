import Foundation
import SwiftData

/// 成就、称号、挑战、商店拥有物的读写入口。
struct ProgressionRepository {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - 解锁记录

    func allUnlocks() -> [UnlockRecord] {
        let descriptor = FetchDescriptor<UnlockRecord>(sortBy: [SortDescriptor(\.unlockedAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func unlockedRuleIDs() -> Set<String> {
        Set(allUnlocks().map(\.ruleID))
    }

    func unlocks(of kind: UnlockKind) -> [UnlockRecord] {
        let raw = kind.rawValue
        let descriptor = FetchDescriptor<UnlockRecord>(
            predicate: #Predicate { $0.kindRaw == raw },
            sortBy: [SortDescriptor(\.unlockedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func unseenUnlockCount() -> Int {
        let descriptor = FetchDescriptor<UnlockRecord>(predicate: #Predicate { $0.isSeen == false })
        return ((try? context.fetch(descriptor)) ?? []).count
    }

    @discardableResult
    func record(ruleID: String, kind: UnlockKind, day: GameDay) -> UnlockRecord {
        let record = UnlockRecord(ruleID: ruleID, kind: kind, day: day)
        context.insert(record)
        return record
    }

    func markAllSeen() {
        for record in allUnlocks() where !record.isSeen {
            record.isSeen = true
        }
    }

    // MARK: - 挑战

    func allChallenges(includeArchived: Bool = false) -> [Challenge] {
        let descriptor = FetchDescriptor<Challenge>(sortBy: [SortDescriptor(\.createdAt)])
        let challenges = (try? context.fetch(descriptor)) ?? []
        return includeArchived ? challenges : challenges.filter { !$0.isArchived }
    }

    func challenge(ruleID: String) -> Challenge? {
        // 谓词里比较的是可选属性，局部变量必须显式声明为可选
        let target: String? = ruleID
        let descriptor = FetchDescriptor<Challenge>(predicate: #Predicate { $0.ruleID == target })
        return (try? context.fetch(descriptor))?.first
    }

    @discardableResult
    func insert(_ challenge: Challenge) -> Challenge {
        context.insert(challenge)
        return challenge
    }

    func delete(_ challenge: Challenge) {
        context.delete(challenge)
    }

    // MARK: - 商店

    func ownedItemIDs() -> Set<String> {
        let descriptor = FetchDescriptor<OwnedItem>()
        return Set(((try? context.fetch(descriptor)) ?? []).map(\.itemID))
    }

    @discardableResult
    func recordPurchase(item: ShopItem) -> OwnedItem {
        let owned = OwnedItem(itemID: item.id, kind: item.kind, pricePaid: item.price)
        context.insert(owned)
        return owned
    }

    // MARK: - 提醒

    func allReminders() -> [Reminder] {
        let descriptor = FetchDescriptor<Reminder>(sortBy: [SortDescriptor(\.createdAt)])
        return (try? context.fetch(descriptor)) ?? []
    }

    @discardableResult
    func insert(_ reminder: Reminder) -> Reminder {
        context.insert(reminder)
        return reminder
    }

    func delete(_ reminder: Reminder) {
        context.delete(reminder)
    }
}
