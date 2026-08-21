import Foundation
import SwiftData

enum StatsRange: String, CaseIterable, Identifiable, Sendable {
    case day, week, month, year, all
    var id: String { rawValue }
}

struct StatsPoint: Identifiable, Sendable {
    var id: Int { day.value }
    var day: GameDay
    var exp: Int
    var gold: Int
    var completed: Int
    var completionRate: Double
    var heatLevel: Int
}

struct StatsSummary: Sendable {
    var range: StatsRange = .week
    var startDay: GameDay = .distantPast
    var endDay: GameDay = .distantPast

    var expEarned: Int = 0
    var goldEarned: Int = 0
    var questsCompleted: Int = 0
    var questsPlanned: Int = 0
    var mainQuestsCompleted: Int = 0
    var sideQuestsCompleted: Int = 0
    var habitCheckIns: Int = 0
    var focusMinutes: Int = 0
    var activeDays: Int = 0
    var perfectDays: Int = 0

    /// 从创建到完成的平均耗时（小时）。反映的是"事情在清单上躺了多久"，
    /// 而不是实际投入时长，因此对识别拖延特别有用。
    var averageTurnaroundHours: Double?

    var points: [StatsPoint] = []

    var completionRate: Double {
        guard questsPlanned > 0 else { return 0 }
        return min(1, Double(questsCompleted) / Double(questsPlanned))
    }

    var mainRatio: Double {
        let total = mainQuestsCompleted + sideQuestsCompleted
        guard total > 0 else { return 0 }
        return Double(mainQuestsCompleted) / Double(total)
    }
}

/// 统计的唯一计算入口。所有聚合都基于 `DailyRecord`，复杂度是 O(天数)，
/// 因此即使积累几年数据，年度视图也不会变慢。
@MainActor
struct StatisticsService {
    private let context: ModelContext
    private let calendar: GameCalendar
    private let config: GameConfig

    init(context: ModelContext, calendar: GameCalendar, config: GameConfig) {
        self.context = context
        self.calendar = calendar
        self.config = config
    }

    func range(_ range: StatsRange, endingAt today: GameDay) -> ClosedRange<GameDay> {
        switch range {
        case .day:
            return today...today
        case .week:
            return calendar.startOfWeek(for: today)...today
        case .month:
            return calendar.startOfMonth(for: today)...today
        case .year:
            return calendar.startOfYear(for: today)...today
        case .all:
            let records = RecordRepository(context: context).allRecords()
            let first = records.first?.day ?? today
            return min(first, today)...today
        }
    }

    func summary(for range: StatsRange, today: GameDay) -> StatsSummary {
        let bounds = self.range(range, endingAt: today)
        let records = RecordRepository(context: context).records(in: bounds)

        var summary = StatsSummary(range: range, startDay: bounds.lowerBound, endDay: bounds.upperBound)
        for record in records {
            summary.expEarned += record.expEarned
            summary.goldEarned += record.goldEarned
            summary.questsCompleted += record.questsCompleted
            summary.questsPlanned += record.questsPlanned
            summary.mainQuestsCompleted += record.mainQuestsCompleted
            summary.sideQuestsCompleted += record.sideQuestsCompleted
            summary.habitCheckIns += record.habitCheckIns
            summary.focusMinutes += record.focusMinutes
            if record.questsCompleted > 0 || record.habitCheckIns > 0 { summary.activeDays += 1 }
            if record.isPerfect { summary.perfectDays += 1 }

            summary.points.append(
                StatsPoint(
                    day: record.day,
                    exp: record.expEarned,
                    gold: record.goldEarned,
                    completed: record.questsCompleted,
                    completionRate: record.completionRate,
                    heatLevel: record.heatLevel
                )
            )
        }

        summary.averageTurnaroundHours = averageTurnaround(in: bounds)
        return summary
    }

    /// 热力图数据。按天返回强度等级，缺失的日子补 0，保证网格是连续的。
    func heatmap(days: Int, endingAt today: GameDay) -> [StatsPoint] {
        let start = calendar.adding(days: -(days - 1), to: today)
        let records = RecordRepository(context: context).records(in: start...today)
        let lookup = Dictionary(uniqueKeysWithValues: records.map { ($0.dayValue, $0) })

        return calendar.days(from: start, through: today).map { day in
            guard let record = lookup[day.value] else {
                return StatsPoint(day: day, exp: 0, gold: 0, completed: 0, completionRate: 0, heatLevel: 0)
            }
            return StatsPoint(
                day: day,
                exp: record.expEarned,
                gold: record.goldEarned,
                completed: record.questsCompleted,
                completionRate: record.completionRate,
                heatLevel: record.heatLevel
            )
        }
    }

    /// 技能成长曲线。按流水回放，得出每一天结束时的技能等级。
    func skillGrowth(skillID: UUID, in bounds: ClosedRange<GameDay>) -> [(day: GameDay, level: Int)] {
        let transactions = RecordRepository(context: context)
            .transactions(in: GameDay.distantPast...bounds.upperBound)
            .sorted { $0.dayValue < $1.dayValue }

        var cumulative = 0
        var perDay: [Int: Int] = [:]
        for transaction in transactions {
            guard let amount = transaction.skillEXP[skillID] else { continue }
            cumulative += amount
            perDay[transaction.dayValue] = cumulative
        }

        var lastKnown = 0
        return calendar.days(from: bounds.lowerBound, through: bounds.upperBound).map { day in
            if let value = perDay[day.value] { lastKnown = value }
            return (day, config.skillCurve.level(forTotalEXP: lastKnown))
        }
    }

    private func averageTurnaround(in bounds: ClosedRange<GameDay>) -> Double? {
        let quests = QuestRepository(context: context)
            .quests(in: bounds)
            .filter { $0.status == .completed && $0.completedAt != nil }
        guard !quests.isEmpty else { return nil }
        let total = quests.reduce(0.0) { partial, quest in
            guard let completedAt = quest.completedAt else { return partial }
            return partial + max(0, completedAt.timeIntervalSince(quest.createdAt))
        }
        return total / Double(quests.count) / 3600
    }
}
