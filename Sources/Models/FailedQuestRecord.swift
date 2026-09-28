import Foundation
import SwiftData

/// 失败任务的快照。任务本身会被取消移出任务栏，这里留下给历史页看的记录。
@Model
final class FailedQuestRecord {
    var id: UUID = UUID()
    var title: String = ""
    var detail: String = ""
    var kindRaw: String = QuestKind.side.rawValue
    var scheduledStartDayValue: Int = 0
    var scheduledEndDayValue: Int = 0
    var failedDayValue: Int = 0
    var failedAt: Date = Date()
    var progressDone: Int = 0
    var progressTarget: Int = 1
    var templateID: UUID?
    var originalQuestID: UUID?

    init(
        title: String,
        detail: String = "",
        kind: QuestKind,
        scheduledStart: GameDay,
        scheduledEnd: GameDay,
        failedDay: GameDay,
        progressDone: Int,
        progressTarget: Int,
        templateID: UUID? = nil,
        originalQuestID: UUID? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.detail = detail
        self.kindRaw = kind.rawValue
        self.scheduledStartDayValue = scheduledStart.value
        self.scheduledEndDayValue = scheduledEnd.value
        self.failedDayValue = failedDay.value
        self.failedAt = Date()
        self.progressDone = progressDone
        self.progressTarget = max(1, progressTarget)
        self.templateID = templateID
        self.originalQuestID = originalQuestID
    }

    var kind: QuestKind { QuestKind(rawValue: kindRaw) ?? .side }
    var scheduledStart: GameDay { GameDay(value: scheduledStartDayValue) }
    var scheduledEnd: GameDay { GameDay(value: scheduledEndDayValue) }
    var failedDay: GameDay { GameDay(value: failedDayValue) }
}

/// 每日结算交给界面的轻量失败条目，不含 SwiftData 引用。
struct FailedQuestSnapshot: Identifiable, Hashable, Sendable {
    var id: UUID
    var title: String
    var progressDone: Int
    var progressTarget: Int

    init(id: UUID = UUID(), title: String, progressDone: Int, progressTarget: Int) {
        self.id = id
        self.title = title
        self.progressDone = progressDone
        self.progressTarget = progressTarget
    }

    init(_ record: FailedQuestRecord) {
        self.id = record.id
        self.title = record.title
        self.progressDone = record.progressDone
        self.progressTarget = record.progressTarget
    }
}
