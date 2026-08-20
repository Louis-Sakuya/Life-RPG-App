import SwiftUI

struct QuestEditorView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    var quest: Quest?
    var defaultDay: GameDay

    @State private var title = ""
    @State private var detail = ""
    @State private var difficulty: QuestDifficulty = .normal
    @State private var priority: QuestPriority = .normal
    @State private var estimatedMinutes = 30
    @State private var tagText = ""
    @State private var scheduledDate = Date()
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var shares: [UUID: Double] = [:]
    @State private var didLoad = false

    var body: some View {
        NavigationStack {
            Form {
                Section("基本") {
                    TextField("任务标题", text: $title)
                    TextField("描述（可选）", text: $detail, axis: .vertical)
                        .lineLimit(1...4)
                    TextField("标签，用空格分隔", text: $tagText)
                        .autocorrectionDisabled()
                }

                Section("难度与优先级") {
                    Picker("难度", selection: $difficulty) {
                        ForEach(QuestDifficulty.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("优先级", selection: $priority) {
                        ForEach(QuestPriority.allCases) { Text($0.title).tag($0) }
                    }
                    Stepper("预计时长 \(estimatedMinutes) 分钟", value: $estimatedMinutes, in: 5...600, step: 5)
                }

                Section {
                    DatePicker("计划执行日", selection: $scheduledDate, displayedComponents: .date)
                    Toggle("设置截止时间", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("截止时间", selection: $dueDate)
                    }
                } header: {
                    Text("排期")
                } footer: {
                    Text(scheduleHint)
                }

                Section("技能经验分配") {
                    SkillShareEditor(skills: store.skills, shares: $shares)
                }

                Section("预计奖励") {
                    rewardPreview
                }
            }
            .navigationTitle(quest == nil ? "新建任务" : "编辑任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    /// 直接把类型派生规则讲给用户听。玩家理解了"提前一天安排能多拿 20%"，
    /// 规划习惯才会真正建立起来。
    private var scheduleHint: String {
        let day = store.container.calendar.gameDay(for: scheduledDate)
        if day > store.today {
            return "计划在今天之后 → 成为主线任务，获得 +20% 提前规划加成"
        }
        return "计划在今天 → 成为支线任务，奖励会打五折"
    }

    private var rewardPreview: some View {
        let day = store.container.calendar.gameDay(for: scheduledDate)
        let engine = RewardEngine(config: store.container.config)
        let context = RewardContext(
            difficulty: difficulty,
            priority: priority,
            estimatedMinutes: estimatedMinutes,
            isPlannedAhead: day > store.today,
            scheduledDay: day,
            completedDay: day,
            dueAt: hasDueDate ? dueDate : nil,
            completedAt: hasDueDate ? dueDate.addingTimeInterval(-60) : Date(),
            globalStreakDays: store.player.loginStreakCurrent,
            skillShares: shares.asSkillShares
        )
        let result = engine.preview(context)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("+\(result.exp) EXP")
                    .font(.headline)
                    .foregroundStyle(palette.accent)
                Text("+\(result.gold) G")
                    .font(.headline)
                    .foregroundStyle(Color(hex: "#D4A017"))
                Spacer()
            }
            ForEach(result.appliedModifiers) { modifier in
                HStack {
                    Text(modifier.label)
                        .font(.caption)
                    Spacer()
                    Text(modifier.signedPercentText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(modifier.value >= 0 ? Color.green : Color.red)
                }
            }
            if result.streakMultiplier > 1 {
                HStack {
                    Text("连续加成")
                        .font(.caption)
                    Spacer()
                    Text("×\(String(format: "%.1f", result.streakMultiplier))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        let calendar = store.container.calendar
        scheduledDate = calendar.displayDate(of: defaultDay)

        guard let quest else { return }
        title = quest.title
        detail = quest.detail
        difficulty = quest.difficulty
        priority = quest.priority
        estimatedMinutes = quest.estimatedMinutes
        tagText = quest.tags.joined(separator: " ")
        scheduledDate = calendar.displayDate(of: quest.scheduledDay)
        if let dueAt = quest.dueAt {
            hasDueDate = true
            dueDate = dueAt
        }
        for link in quest.skillLinks ?? [] {
            shares[link.skillID] = link.expShare
        }
    }

    private func save() {
        let calendar = store.container.calendar
        let day = calendar.gameDay(for: scheduledDate)
        let tags = tagText
            .split(whereSeparator: { $0 == " " || $0 == "," || $0 == "，" })
            .map(String.init)
            .filter { !$0.isEmpty }

        if let quest {
            store.updateQuest(
                quest,
                title: title,
                detail: detail,
                difficulty: difficulty,
                priority: priority,
                tags: tags,
                estimatedMinutes: estimatedMinutes,
                scheduledDay: day,
                dueAt: hasDueDate ? dueDate : nil,
                skillShares: shares.asSkillShares
            )
        } else {
            store.createQuest(
                title: title,
                detail: detail,
                difficulty: difficulty,
                priority: priority,
                tags: tags,
                estimatedMinutes: estimatedMinutes,
                scheduledDay: day,
                dueAt: hasDueDate ? dueDate : nil,
                skillShares: shares.asSkillShares
            )
        }
        dismiss()
    }
}
