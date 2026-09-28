import SwiftUI

struct QuestEditorView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    var quest: Quest?
    var defaultDay: GameDay

    @State private var title = ""
    @State private var detail = ""
    @State private var estimatedMinutes = 30
    @State private var priority: QuestPriority = .normal
    @State private var tagText = ""
    @State private var scheduledDate = Date()
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var selectedSkillIDs: Set<UUID> = []
    @State private var didLoad = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.t("quest.title_placeholder"), text: $title)
                    TextField(L10n.t("quest.detail_placeholder"), text: $detail, axis: .vertical)
                        .lineLimit(1...4)
                    TextField(L10n.t("quest.tags_placeholder"), text: $tagText)
                        .autocorrectionDisabled()
                    QuestChallengeFields(estimatedMinutes: $estimatedMinutes, priority: $priority)
                } header: {
                    Text(L10n.t("common.basic"))
                } footer: {
                    Text(L10n.t("quest.difficulty.auto_footer"))
                }

                Section {
                    DatePicker(L10n.t("quest.scheduled_day"), selection: $scheduledDate, displayedComponents: .date)
                    Toggle(L10n.t("quest.set_due"), isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker(L10n.t("quest.due_at"), selection: $dueDate)
                    }
                } header: {
                    Text(L10n.t("common.schedule"))
                } footer: {
                    Text(scheduleHint)
                }

                Section {
                    SkillPickList(skills: store.skills, selectedIDs: $selectedSkillIDs)
                } header: {
                    Text(L10n.t("wizard.skill_header"))
                } footer: {
                    Text(L10n.t("wizard.skill_footer"))
                }

                Section(L10n.t("quest.reward_preview")) {
                    rewardPreview
                }
            }
            .navigationTitle(quest == nil ? L10n.t("quest.new") : L10n.t("quest.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("common.save"), action: save)
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: load)
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var skillShares: [SkillShare] {
        SkillShareMath.selected(store.skills.map(\.id).filter { selectedSkillIDs.contains($0) }).asSkillShares
    }

    /// 直接把类型派生规则讲给用户听。玩家理解了"提前一天安排能多拿 20%"，
    /// 规划习惯才会真正建立起来。
    private var scheduleHint: String {
        let day = store.container.calendar.gameDay(fromDisplayDate: scheduledDate)
        if day > store.today {
            return L10n.t("quest.hint.planned")
        }
        return L10n.t("quest.hint.today")
    }

    private var rewardPreview: some View {
        let day = store.container.calendar.gameDay(fromDisplayDate: scheduledDate)
        let engine = RewardEngine(config: store.container.config)
        let context = RewardContext(
            difficulty: .fromEstimatedMinutes(estimatedMinutes),
            priority: priority,
            estimatedMinutes: estimatedMinutes,
            isPlannedAhead: day > store.today,
            scheduledDay: day,
            completedDay: day,
            dueAt: hasDueDate ? dueDate : nil,
            completedAt: hasDueDate ? dueDate.addingTimeInterval(-60) : Date(),
            globalStreakDays: store.player.loginStreakCurrent,
            skillShares: skillShares
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
                    Text(modifier.localizedLabel)
                        .font(.caption)
                    Spacer()
                    Text(modifier.signedPercentText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(modifier.value >= 0 ? Color.green : Color.red)
                }
            }
            if result.streakMultiplier > 1 {
                HStack {
                    Text(L10n.t("quest.streak_bonus"))
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

        if let quest {
            title = quest.title
            detail = quest.detail
            estimatedMinutes = quest.estimatedMinutes
            priority = quest.priority
            tagText = quest.tags.joined(separator: " ")
            scheduledDate = calendar.displayDate(of: quest.scheduledDay)
            if let dueAt = quest.dueAt {
                hasDueDate = true
                dueDate = dueAt
            }
            selectedSkillIDs = Set((quest.skillLinks ?? []).map(\.skillID))
        }
    }

    private func save() {
        let calendar = store.container.calendar
        let day = calendar.gameDay(fromDisplayDate: scheduledDate)
        let tags = tagText
            .split(whereSeparator: { $0 == " " || $0 == "," || $0 == "，" })
            .map(String.init)
            .filter { !$0.isEmpty }

        if let quest {
            store.updateQuest(
                quest,
                title: title,
                detail: detail,
                difficulty: .fromEstimatedMinutes(estimatedMinutes),
                priority: priority,
                tags: tags,
                estimatedMinutes: estimatedMinutes,
                scheduledDay: day,
                dueAt: hasDueDate ? dueDate : nil,
                skillShares: skillShares
            )
        } else {
            store.createQuest(
                title: title,
                detail: detail,
                difficulty: .fromEstimatedMinutes(estimatedMinutes),
                priority: priority,
                tags: tags,
                estimatedMinutes: estimatedMinutes,
                scheduledDay: day,
                dueAt: hasDueDate ? dueDate : nil,
                skillShares: skillShares
            )
        }
        dismiss()
    }
}
