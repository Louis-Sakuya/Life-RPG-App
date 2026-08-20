import Foundation
import SwiftData
import UIKit

/// 备份文件的载荷。刻意用独立的 DTO 而不是直接序列化 `@Model`：
/// 备份格式一旦发布就要长期兼容，不应该被数据库结构的调整牵着走。
struct BackupPayload: Codable {
    struct PlayerDTO: Codable {
        var nickname: String
        var avatarSymbol: String
        var totalEXP: Int
        var gold: Int
        var currentTitleID: String?
        var currentThemeID: String
        var currentFrameID: String?
        var loginStreakCurrent: Int
        var loginStreakBest: Int
        var lastLoginDayValue: Int
        var lastActiveDayValue: Int
        var totalDaysPlayed: Int
        var totalQuestsCompleted: Int
        var totalMainQuestsCompleted: Int
        var totalSideQuestsCompleted: Int
        var totalHabitCheckIns: Int
        var totalEXPEarned: Int
        var totalGoldEarned: Int
        var totalStudyMinutes: Int
        var totalFocusMinutes: Int
        var perfectDays: Int
        var earliestCompletionHour: Int
        var latestCompletionHour: Int
        /// 可选，旧版本备份没有这个字段
        var highestLevelRewarded: Int?
    }

    struct SkillDTO: Codable {
        var id: UUID
        var name: String
        var iconName: String
        var colorHex: String
        var totalEXP: Int
        var sortOrder: Int
        var isArchived: Bool
    }

    struct QuestDTO: Codable {
        var id: UUID
        var title: String
        var detail: String
        var kind: String
        var status: String
        var difficulty: Int
        var priority: Int
        var tags: [String]
        var estimatedMinutes: Int
        var createdDayValue: Int
        var scheduledDayValue: Int
        var completedDayValue: Int
        var dueAt: Date?
        var completedAt: Date?
        var isOverdue: Bool
        var templateID: UUID?
        var skillShares: [String]
    }

    struct HabitDTO: Codable {
        var id: UUID
        var name: String
        var iconName: String
        var colorHex: String
        var dailyTarget: Int
        var reminderHour: Int
        var reminderMinute: Int
        var streakCurrent: Int
        var streakBest: Int
        var streakLastDayValue: Int
        var totalCheckIns: Int
        var isArchived: Bool
        var logs: [HabitLogDTO]
    }

    struct HabitLogDTO: Codable {
        var dayValue: Int
        var count: Int
    }

    struct DailyRecordDTO: Codable {
        var dayValue: Int
        var expEarned: Int
        var goldEarned: Int
        var questsCompleted: Int
        var questsPlanned: Int
        var mainQuestsCompleted: Int
        var sideQuestsCompleted: Int
        var habitCheckIns: Int
        var habitTargets: Int
        var focusMinutes: Int
        var studyMinutes: Int
        var isFinalized: Bool
    }

    struct UnlockDTO: Codable {
        var ruleID: String
        var kind: String
        var unlockedDayValue: Int
    }

    var formatVersion: Int = 1
    var exportedAt: Date = Date()
    var player: PlayerDTO
    var skills: [SkillDTO]
    var quests: [QuestDTO]
    var habits: [HabitDTO]
    var dailyRecords: [DailyRecordDTO]
    var unlocks: [UnlockDTO]
    var ownedItemIDs: [String]
}

/// 数据导出与备份恢复。全部产出写到临时目录，由系统分享面板接管。
@MainActor
final class ExportService {
    private let context: ModelContext
    private let config: GameConfig
    private let calendar: GameCalendar

    init(context: ModelContext, config: GameConfig, calendar: GameCalendar) {
        self.context = context
        self.config = config
        self.calendar = calendar
    }

    // MARK: - JSON 备份

    func makeBackup() throws -> URL {
        let payload = buildPayload()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        return try write(data, name: "LifeRPG-Backup-\(timestamp()).json")
    }

    /// 恢复采用"清空后重建"，而不是逐条合并。
    /// 合并需要处理 id 冲突、部分成功等大量边界，对一个本地应用来说收益不成正比。
    func restore(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(BackupPayload.self, from: data)

        try wipeAll()
        apply(payload)
        try context.save()
    }

    // MARK: - CSV

    func exportQuestsCSV() throws -> URL {
        var rows = ["日期,标题,类型,状态,难度,优先级,预计分钟,标签,完成时间,是否延期"]
        let formatter = ISO8601DateFormatter()
        for quest in QuestRepository(context: context).allQuests() {
            let completed = quest.completedAt.map { formatter.string(from: $0) } ?? ""
            rows.append([
                quest.scheduledDay.description,
                escape(quest.title),
                quest.kind.title,
                quest.status.rawValue,
                String(quest.difficultyRaw),
                String(quest.priorityRaw),
                String(quest.estimatedMinutes),
                escape(quest.tags.joined(separator: "|")),
                completed,
                quest.isOverdue ? "是" : "否"
            ].joined(separator: ","))
        }
        return try write(csvData(rows), name: "LifeRPG-Quests-\(timestamp()).csv")
    }

    func exportDailyRecordsCSV() throws -> URL {
        var rows = ["日期,获得EXP,获得Gold,计划任务,完成任务,主线完成,支线完成,习惯打卡,习惯目标,完成率,专注分钟"]
        for record in RecordRepository(context: context).allRecords() {
            rows.append([
                record.day.description,
                String(record.expEarned),
                String(record.goldEarned),
                String(record.questsPlanned),
                String(record.questsCompleted),
                String(record.mainQuestsCompleted),
                String(record.sideQuestsCompleted),
                String(record.habitCheckIns),
                String(record.habitTargets),
                String(format: "%.2f", record.completionRate),
                String(record.focusMinutes)
            ].joined(separator: ","))
        }
        return try write(csvData(rows), name: "LifeRPG-Daily-\(timestamp()).csv")
    }

    // MARK: - PDF

    /// 一页纸的成长报告，用于分享或存档
    func exportSummaryPDF(player: Player) throws -> URL {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let progress = config.playerCurve.progress(totalEXP: player.totalEXP)
        let skills = SkillRepository(context: context).allSkills()
        let records = RecordRepository(context: context).allRecords()

        let data = renderer.pdfData { pdfContext in
            pdfContext.beginPage()
            var cursor: CGFloat = 48

            draw("Life RPG 成长报告", at: &cursor, size: 26, weight: .bold, pageRect: pageRect)
            draw(dateText(), at: &cursor, size: 12, weight: .regular, pageRect: pageRect)
            cursor += 16

            draw("角色", at: &cursor, size: 18, weight: .semibold, pageRect: pageRect)
            draw("昵称：\(player.nickname)", at: &cursor, size: 13, weight: .regular, pageRect: pageRect)
            draw("等级：Lv\(progress.level)（\(progress.currentEXP)/\(max(progress.requiredEXP, 1)) EXP）", at: &cursor, size: 13, weight: .regular, pageRect: pageRect)
            draw("金币：\(player.gold)", at: &cursor, size: 13, weight: .regular, pageRect: pageRect)
            draw("连续登录：\(player.loginStreakCurrent) 天（最长 \(player.loginStreakBest) 天）", at: &cursor, size: 13, weight: .regular, pageRect: pageRect)
            draw("累计天数：\(player.totalDaysPlayed)", at: &cursor, size: 13, weight: .regular, pageRect: pageRect)
            cursor += 12

            draw("任务", at: &cursor, size: 18, weight: .semibold, pageRect: pageRect)
            draw("累计完成：\(player.totalQuestsCompleted)（主线 \(player.totalMainQuestsCompleted) / 支线 \(player.totalSideQuestsCompleted)）", at: &cursor, size: 13, weight: .regular, pageRect: pageRect)
            draw("习惯打卡：\(player.totalHabitCheckIns) 次", at: &cursor, size: 13, weight: .regular, pageRect: pageRect)
            draw("完美达成天数：\(player.perfectDays)", at: &cursor, size: 13, weight: .regular, pageRect: pageRect)
            cursor += 12

            draw("技能", at: &cursor, size: 18, weight: .semibold, pageRect: pageRect)
            for skill in skills.prefix(20) {
                let level = config.skillCurve.level(forTotalEXP: skill.totalEXP)
                draw("\(skill.name)  Lv\(level)  （\(skill.totalEXP) EXP）", at: &cursor, size: 13, weight: .regular, pageRect: pageRect)
            }
            cursor += 12

            draw("统计", at: &cursor, size: 18, weight: .semibold, pageRect: pageRect)
            let totalEXP = records.reduce(0) { $0 + $1.expEarned }
            let totalGold = records.reduce(0) { $0 + $1.goldEarned }
            let activeDays = records.filter { $0.questsCompleted > 0 || $0.habitCheckIns > 0 }.count
            draw("有记录天数：\(records.count)，其中活跃 \(activeDays) 天", at: &cursor, size: 13, weight: .regular, pageRect: pageRect)
            draw("累计获得：\(totalEXP) EXP / \(totalGold) Gold", at: &cursor, size: 13, weight: .regular, pageRect: pageRect)
        }

        return try write(data, name: "LifeRPG-Report-\(timestamp()).pdf")
    }

    // MARK: - 内部

    private func buildPayload() -> BackupPayload {
        let players = PlayerRepository(context: context)
        let questRepo = QuestRepository(context: context)
        let skillRepo = SkillRepository(context: context)
        let habitRepo = HabitRepository(context: context)
        let recordRepo = RecordRepository(context: context)
        let progression = ProgressionRepository(context: context)
        let player = players.currentPlayer()

        return BackupPayload(
            player: BackupPayload.PlayerDTO(
                nickname: player.nickname,
                avatarSymbol: player.avatarSymbol,
                totalEXP: player.totalEXP,
                gold: player.gold,
                currentTitleID: player.currentTitleID,
                currentThemeID: player.currentThemeID,
                currentFrameID: player.currentFrameID,
                loginStreakCurrent: player.loginStreakCurrent,
                loginStreakBest: player.loginStreakBest,
                lastLoginDayValue: player.lastLoginDayValue,
                lastActiveDayValue: player.lastActiveDayValue,
                totalDaysPlayed: player.totalDaysPlayed,
                totalQuestsCompleted: player.totalQuestsCompleted,
                totalMainQuestsCompleted: player.totalMainQuestsCompleted,
                totalSideQuestsCompleted: player.totalSideQuestsCompleted,
                totalHabitCheckIns: player.totalHabitCheckIns,
                totalEXPEarned: player.totalEXPEarned,
                totalGoldEarned: player.totalGoldEarned,
                totalStudyMinutes: player.totalStudyMinutes,
                totalFocusMinutes: player.totalFocusMinutes,
                perfectDays: player.perfectDays,
                earliestCompletionHour: player.earliestCompletionHour,
                latestCompletionHour: player.latestCompletionHour,
                highestLevelRewarded: player.highestLevelRewarded
            ),
            skills: skillRepo.allSkills(includeArchived: true).map {
                BackupPayload.SkillDTO(
                    id: $0.id,
                    name: $0.name,
                    iconName: $0.iconName,
                    colorHex: $0.colorHex,
                    totalEXP: $0.totalEXP,
                    sortOrder: $0.sortOrder,
                    isArchived: $0.isArchived
                )
            },
            quests: questRepo.allQuests().map { quest in
                BackupPayload.QuestDTO(
                    id: quest.id,
                    title: quest.title,
                    detail: quest.detail,
                    kind: quest.kindRaw,
                    status: quest.statusRaw,
                    difficulty: quest.difficultyRaw,
                    priority: quest.priorityRaw,
                    tags: quest.tags,
                    estimatedMinutes: quest.estimatedMinutes,
                    createdDayValue: quest.createdDayValue,
                    scheduledDayValue: quest.scheduledDayValue,
                    completedDayValue: quest.completedDayValue,
                    dueAt: quest.dueAt,
                    completedAt: quest.completedAt,
                    isOverdue: quest.isOverdue,
                    templateID: quest.templateID,
                    skillShares: questRepo.skillShares(of: quest).map(\.token)
                )
            },
            habits: habitRepo.allHabits(includeArchived: true).map { habit in
                BackupPayload.HabitDTO(
                    id: habit.id,
                    name: habit.name,
                    iconName: habit.iconName,
                    colorHex: habit.colorHex,
                    dailyTarget: habit.dailyTarget,
                    reminderHour: habit.reminderHour,
                    reminderMinute: habit.reminderMinute,
                    streakCurrent: habit.streakCurrent,
                    streakBest: habit.streakBest,
                    streakLastDayValue: habit.streakLastDayValue,
                    totalCheckIns: habit.totalCheckIns,
                    isArchived: habit.isArchived,
                    logs: (habit.logs ?? []).map {
                        BackupPayload.HabitLogDTO(dayValue: $0.dayValue, count: $0.count)
                    }
                )
            },
            dailyRecords: recordRepo.allRecords().map {
                BackupPayload.DailyRecordDTO(
                    dayValue: $0.dayValue,
                    expEarned: $0.expEarned,
                    goldEarned: $0.goldEarned,
                    questsCompleted: $0.questsCompleted,
                    questsPlanned: $0.questsPlanned,
                    mainQuestsCompleted: $0.mainQuestsCompleted,
                    sideQuestsCompleted: $0.sideQuestsCompleted,
                    habitCheckIns: $0.habitCheckIns,
                    habitTargets: $0.habitTargets,
                    focusMinutes: $0.focusMinutes,
                    studyMinutes: $0.studyMinutes,
                    isFinalized: $0.isFinalized
                )
            },
            unlocks: progression.allUnlocks().map {
                BackupPayload.UnlockDTO(
                    ruleID: $0.ruleID,
                    kind: $0.kindRaw,
                    unlockedDayValue: $0.unlockedDayValue
                )
            },
            ownedItemIDs: Array(progression.ownedItemIDs())
        )
    }

    /// SwiftData 的 `delete(model:)` 是泛型接口，无法用 `any PersistentModel.Type` 遍历调用，
    /// 因此这里必须逐个实体显式写出来。新增实体时记得同步补充。
    private func wipeAll() throws {
        try context.delete(model: QuestSkillLink.self)
        try context.delete(model: Quest.self)
        try context.delete(model: QuestTemplate.self)
        try context.delete(model: HabitLog.self)
        try context.delete(model: Habit.self)
        try context.delete(model: Skill.self)
        try context.delete(model: Challenge.self)
        try context.delete(model: UnlockRecord.self)
        try context.delete(model: DailyRecord.self)
        try context.delete(model: RewardTransaction.self)
        try context.delete(model: Reminder.self)
        try context.delete(model: OwnedItem.self)
        try context.delete(model: AppSettings.self)
        try context.delete(model: Player.self)
    }

    private func apply(_ payload: BackupPayload) {
        let player = Player(nickname: payload.player.nickname)
        player.avatarSymbol = payload.player.avatarSymbol
        player.totalEXP = payload.player.totalEXP
        player.gold = payload.player.gold
        player.currentTitleID = payload.player.currentTitleID
        player.currentThemeID = payload.player.currentThemeID
        player.currentFrameID = payload.player.currentFrameID
        player.loginStreakCurrent = payload.player.loginStreakCurrent
        player.loginStreakBest = payload.player.loginStreakBest
        player.lastLoginDayValue = payload.player.lastLoginDayValue
        player.lastActiveDayValue = payload.player.lastActiveDayValue
        player.totalDaysPlayed = payload.player.totalDaysPlayed
        player.totalQuestsCompleted = payload.player.totalQuestsCompleted
        player.totalMainQuestsCompleted = payload.player.totalMainQuestsCompleted
        player.totalSideQuestsCompleted = payload.player.totalSideQuestsCompleted
        player.totalHabitCheckIns = payload.player.totalHabitCheckIns
        player.totalEXPEarned = payload.player.totalEXPEarned
        player.totalGoldEarned = payload.player.totalGoldEarned
        player.totalStudyMinutes = payload.player.totalStudyMinutes
        player.totalFocusMinutes = payload.player.totalFocusMinutes
        player.perfectDays = payload.player.perfectDays
        player.earliestCompletionHour = payload.player.earliestCompletionHour
        player.latestCompletionHour = payload.player.latestCompletionHour
        player.highestLevelRewarded = payload.player.highestLevelRewarded
            ?? config.playerCurve.level(forTotalEXP: payload.player.totalEXP)
        context.insert(player)
        context.insert(AppSettings())

        for dto in payload.skills {
            let skill = Skill(name: dto.name, iconName: dto.iconName, colorHex: dto.colorHex, sortOrder: dto.sortOrder)
            skill.id = dto.id
            skill.totalEXP = dto.totalEXP
            skill.isArchived = dto.isArchived
            context.insert(skill)
        }

        for dto in payload.quests {
            let quest = Quest(
                title: dto.title,
                detail: dto.detail,
                kind: QuestKind(rawValue: dto.kind) ?? .side,
                difficulty: QuestDifficulty(rawValue: dto.difficulty) ?? .normal,
                priority: QuestPriority(rawValue: dto.priority) ?? .normal,
                tags: dto.tags,
                estimatedMinutes: dto.estimatedMinutes,
                createdDay: GameDay(value: dto.createdDayValue),
                scheduledDay: GameDay(value: dto.scheduledDayValue),
                dueAt: dto.dueAt,
                templateID: dto.templateID
            )
            quest.id = dto.id
            quest.statusRaw = dto.status
            quest.completedAt = dto.completedAt
            quest.completedDayValue = dto.completedDayValue
            quest.isOverdue = dto.isOverdue
            context.insert(quest)
            quest.skillLinks = []
            for token in dto.skillShares {
                guard let share = SkillShare(token: token) else { continue }
                let link = QuestSkillLink(skillID: share.skillID, expShare: share.expShare)
                link.quest = quest
                context.insert(link)
                quest.skillLinks?.append(link)
            }
        }

        for dto in payload.habits {
            let habit = Habit(
                name: dto.name,
                iconName: dto.iconName,
                colorHex: dto.colorHex,
                dailyTarget: dto.dailyTarget
            )
            habit.id = dto.id
            habit.reminderHour = dto.reminderHour
            habit.reminderMinute = dto.reminderMinute
            habit.streakCurrent = dto.streakCurrent
            habit.streakBest = dto.streakBest
            habit.streakLastDayValue = dto.streakLastDayValue
            habit.totalCheckIns = dto.totalCheckIns
            habit.isArchived = dto.isArchived
            context.insert(habit)
            habit.logs = []
            for logDTO in dto.logs {
                let log = HabitLog(day: GameDay(value: logDTO.dayValue), count: logDTO.count)
                log.habit = habit
                context.insert(log)
                habit.logs?.append(log)
            }
        }

        for dto in payload.dailyRecords {
            let record = DailyRecord(day: GameDay(value: dto.dayValue))
            record.expEarned = dto.expEarned
            record.goldEarned = dto.goldEarned
            record.questsCompleted = dto.questsCompleted
            record.questsPlanned = dto.questsPlanned
            record.mainQuestsCompleted = dto.mainQuestsCompleted
            record.sideQuestsCompleted = dto.sideQuestsCompleted
            record.habitCheckIns = dto.habitCheckIns
            record.habitTargets = dto.habitTargets
            record.focusMinutes = dto.focusMinutes
            record.studyMinutes = dto.studyMinutes
            record.isFinalized = dto.isFinalized
            context.insert(record)
        }

        for dto in payload.unlocks {
            context.insert(
                UnlockRecord(
                    ruleID: dto.ruleID,
                    kind: UnlockKind(rawValue: dto.kind) ?? .achievement,
                    day: GameDay(value: dto.unlockedDayValue)
                )
            )
        }

        for itemID in payload.ownedItemIDs {
            guard let item = config.shop.item(id: itemID) else { continue }
            context.insert(OwnedItem(itemID: item.id, kind: item.kind, pricePaid: item.price))
        }
    }

    private func csvData(_ rows: [String]) -> Data {
        // BOM 头让 Excel 正确识别 UTF-8，否则中文列名会乱码
        let bom = Data([0xEF, 0xBB, 0xBF])
        return bom + Data(rows.joined(separator: "\n").utf8)
    }

    private func escape(_ text: String) -> String {
        guard text.contains(",") || text.contains("\"") || text.contains("\n") else { return text }
        return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private func write(_ data: Data, name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }

    private func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return formatter.string(from: Date())
    }

    private func dateText() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return "导出于 " + formatter.string(from: Date())
    }

    private func draw(
        _ text: String,
        at cursor: inout CGFloat,
        size: CGFloat,
        weight: UIFont.Weight,
        pageRect: CGRect
    ) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: UIColor.black
        ]
        let rect = CGRect(x: 48, y: cursor, width: pageRect.width - 96, height: size + 8)
        (text as NSString).draw(in: rect, withAttributes: attributes)
        cursor += size + 10
    }
}
