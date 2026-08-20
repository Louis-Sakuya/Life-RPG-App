import Foundation
import SwiftData

/// 每日聚合与奖励流水的读写入口。统计系统的所有查询都从这里出发。
struct RecordRepository {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - DailyRecord

    func record(on day: GameDay) -> DailyRecord? {
        let value = day.value
        let descriptor = FetchDescriptor<DailyRecord>(predicate: #Predicate { $0.dayValue == value })
        return (try? context.fetch(descriptor))?.first
    }

    @discardableResult
    func ensureRecord(on day: GameDay) -> DailyRecord {
        if let existing = record(on: day) { return existing }
        let created = DailyRecord(day: day)
        context.insert(created)
        return created
    }

    func records(in range: ClosedRange<GameDay>) -> [DailyRecord] {
        let lower = range.lowerBound.value
        let upper = range.upperBound.value
        let descriptor = FetchDescriptor<DailyRecord>(
            predicate: #Predicate { $0.dayValue >= lower && $0.dayValue <= upper },
            sortBy: [SortDescriptor(\.dayValue)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func allRecords() -> [DailyRecord] {
        let descriptor = FetchDescriptor<DailyRecord>(sortBy: [SortDescriptor(\.dayValue)])
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - RewardTransaction

    @discardableResult
    func insert(_ transaction: RewardTransaction) -> RewardTransaction {
        context.insert(transaction)
        return transaction
    }

    /// 某来源尚未撤销的流水。撤销完成时按这些记录反向回滚。
    func activeTransactions(sourceID: UUID) -> [RewardTransaction] {
        // 谓词里比较的是可选属性，局部变量必须显式声明为可选
        let target: UUID? = sourceID
        let descriptor = FetchDescriptor<RewardTransaction>(
            predicate: #Predicate { $0.sourceID == target && $0.isReverted == false },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// 某来源在指定日的未撤销流水。习惯是按天重复达成的，
    /// 撤销打卡时只能回滚当天那一笔，不能把历史全部倒扣。
    func activeTransactions(sourceID: UUID, on day: GameDay) -> [RewardTransaction] {
        let value = day.value
        let target: UUID? = sourceID
        let descriptor = FetchDescriptor<RewardTransaction>(
            predicate: #Predicate {
                $0.sourceID == target && $0.dayValue == value && $0.isReverted == false
            },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func transactions(in range: ClosedRange<GameDay>) -> [RewardTransaction] {
        let lower = range.lowerBound.value
        let upper = range.upperBound.value
        let descriptor = FetchDescriptor<RewardTransaction>(
            predicate: #Predicate { $0.dayValue >= lower && $0.dayValue <= upper && $0.isReverted == false },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func recentTransactions(limit: Int = 50) -> [RewardTransaction] {
        var descriptor = FetchDescriptor<RewardTransaction>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    func allTransactions() -> [RewardTransaction] {
        let descriptor = FetchDescriptor<RewardTransaction>(sortBy: [SortDescriptor(\.createdAt)])
        return (try? context.fetch(descriptor)) ?? []
    }
}
