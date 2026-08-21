import SwiftUI

/// 工会接待处。用问答把一次发布拆成：任务栏 → 主线形态 → 填写细节。
struct QuestPublishWizardView: View {
    enum BoardKind {
        case main, side
    }

    enum MainKind {
        case recurring, urgent
    }

    enum LongTermMode: String, CaseIterable, Identifiable {
        case recurrence
        case dateRange

        var id: String { rawValue }

        var title: String {
            switch self {
            case .recurrence: return L10n.t("longterm.recurrence")
            case .dateRange: return L10n.t("longterm.range")
            }
        }
    }

    private enum Step {
        case boardKind
        case mainKind
        case details
    }

    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    var initialBoardKind: BoardKind? = nil

    @State private var step: Step = .boardKind
    @State private var boardKind: BoardKind = .main
    @State private var mainKind: MainKind = .urgent
    @State private var longTermMode: LongTermMode = .recurrence

    @State private var title = ""
    @State private var detail = ""
    @State private var difficulty: QuestDifficulty = .normal
    @State private var priority: QuestPriority = .normal
    @State private var estimatedMinutes = 30
    @State private var shares: [UUID: Double] = [:]
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var dueTime = Date()
    @State private var hasEndDay = false
    @State private var recurrenceEndDate = Date()

    @State private var recurrenceMode: RecurrenceMode = .daily
    @State private var dailyInterval = 1
    @State private var weekdays: Set<Int> = [2, 4, 6]
    @State private var timesPerWeek = 3
    @State private var monthDays: Set<Int> = [1]
    @State private var startPolicy: RecurrenceStartPolicy = .thisPeriod

    @State private var didLoad = false

    private var calendar: GameCalendar { store.container.calendar }
    private var goldTint: Color { Color(hex: "#D4A017") }

    private var isLongTerm: Bool {
        boardKind == .main && mainKind == .recurring
    }

    private var canPublish: Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if store.skills.isEmpty { return true }
        return SkillShareMath.isFullAllocation(shares)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .boardKind:
                    boardKindStep
                case .mainKind:
                    mainKindStep
                case .details:
                    detailsStep
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(step == .boardKind ? L10n.t("wizard.cancel") : L10n.t("common.back"), action: goBack)
                }
                if step == .details {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.t("wizard.post"), action: publish)
                            .disabled(!canPublish)
                    }
                }
            }
            .onAppear(perform: bootstrap)
        }
    }

    private var navigationTitle: String {
        switch step {
        case .boardKind: return L10n.t("wizard.title.publish")
        case .mainKind: return L10n.t("wizard.title.main_kind")
        case .details: return isLongTerm ? L10n.t("wizard.title.repeat") : L10n.t("wizard.title.details")
        }
    }

    // MARK: - A. 任务栏

    private var boardKindStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                wizardQuestion(
                    eyebrow: L10n.t("wizard.step1.eyebrow"),
                    title: L10n.t("wizard.step1.title"),
                    subtitle: L10n.t("wizard.step1.subtitle")
                )

                GuildChoiceCard(
                    icon: "flag.fill",
                    title: L10n.t("wizard.main.title"),
                    subtitle: L10n.t("wizard.main.subtitle"),
                    detail: L10n.t("wizard.main.detail"),
                    tint: palette.accent
                ) {
                    boardKind = .main
                    step = .mainKind
                }

                GuildChoiceCard(
                    icon: "bolt.fill",
                    title: L10n.t("wizard.side.title"),
                    subtitle: L10n.t("wizard.side.subtitle"),
                    detail: L10n.t("wizard.side.detail"),
                    tint: .orange
                ) {
                    boardKind = .side
                    prepareDetails()
                    step = .details
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - B. 主线形态

    private var mainKindStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                wizardQuestion(
                    eyebrow: L10n.t("wizard.step2.eyebrow"),
                    title: L10n.t("wizard.step2.title"),
                    subtitle: L10n.t("wizard.step2.subtitle")
                )

                GuildChoiceCard(
                    icon: "repeat",
                    title: L10n.t("wizard.long.title"),
                    subtitle: L10n.t("wizard.long.subtitle"),
                    detail: L10n.t("wizard.long.detail"),
                    tint: .teal
                ) {
                    mainKind = .recurring
                    prepareDetails()
                    step = .details
                }

                GuildChoiceCard(
                    icon: "exclamationmark.triangle.fill",
                    title: L10n.t("wizard.urgent.title"),
                    subtitle: L10n.t("wizard.urgent.subtitle"),
                    detail: L10n.t("wizard.urgent.detail"),
                    tint: Color(hex: "#E2603B")
                ) {
                    mainKind = .urgent
                    prepareDetails()
                    step = .details
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - C / D. 细节

    private var detailsStep: some View {
        Form {
            Section {
                Text(detailsEyebrow)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.accent)
                TextField(L10n.t("wizard.field.title"), text: $title)
                TextField(L10n.t("wizard.field.detail"), text: $detail, axis: .vertical)
                    .lineLimit(1...4)
            } header: {
                Text(L10n.t("wizard.notice"))
            }

            Section(L10n.t("wizard.difficulty_section")) {
                Picker(L10n.t("common.difficulty"), selection: $difficulty) {
                    ForEach(QuestDifficulty.allCases) { Text($0.title).tag($0) }
                }
                HStack {
                    DifficultyStars(value: difficulty.rawValue, tint: .orange)
                    Text(difficultyRewardText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                Picker(L10n.t("common.priority"), selection: $priority) {
                    ForEach(QuestPriority.allCases) { Text($0.title).tag($0) }
                }
                Stepper(L10n.format("quest.estimated_stepper", estimatedMinutes), value: $estimatedMinutes, in: 5...600, step: 5)
            }

            Section {
                SkillShareEditor(skills: store.skills, shares: $shares, requiresFullAllocation: true)
            } header: {
                Text(L10n.t("wizard.skill_header"))
            } footer: {
                Text(L10n.t("wizard.skill_footer"))
            }

            if isLongTerm {
                longTermScheduleSections
            } else {
                oneShotScheduleSection
            }

            Section(L10n.t("wizard.reward_section")) {
                rewardPreview
            }
        }
    }

    private var detailsEyebrow: String {
        switch (boardKind, mainKind, isLongTerm) {
        case (.side, _, _):
            return L10n.t("wizard.type.side")
        case (.main, .urgent, _):
            return L10n.t("wizard.type.urgent")
        default:
            return L10n.t("wizard.type.long")
        }
    }

    private var oneShotScheduleSection: some View {
        Section {
            if boardKind == .side {
                LabeledContent(L10n.t("wizard.start_date"), value: L10n.t("wizard.start_today_fixed"))
            } else {
                DatePicker(
                    L10n.t("wizard.start_date"),
                    selection: $startDate,
                    in: calendar.displayDate(of: store.today)...,
                    displayedComponents: .date
                )
            }
            DatePicker(L10n.t("wizard.due_time"), selection: $dueTime, displayedComponents: .hourAndMinute)
        } header: {
            Text(L10n.t("wizard.schedule"))
        } footer: {
            Text(oneShotFooter)
        }
    }

    private var oneShotFooter: String {
        if boardKind == .side {
            return L10n.t("wizard.hint.side")
        }
        let day = calendar.gameDay(fromDisplayDate: startDate)
        if day > store.today {
            return L10n.t("wizard.hint.ahead")
        }
        return L10n.t("wizard.hint.today_main")
    }

    @ViewBuilder
    private var longTermScheduleSections: some View {
        Section {
            Picker(L10n.t("wizard.long_mode"), selection: $longTermMode) {
                ForEach(LongTermMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
        } header: {
            Text(L10n.t("wizard.long_how"))
        } footer: {
            Text(longTermMode == .recurrence
                 ? L10n.t("wizard.long_recurrence_footer")
                 : L10n.t("wizard.long_range_footer"))
        }

        if longTermMode == .recurrence {
            RecurrenceEditor(
                mode: $recurrenceMode,
                dailyInterval: $dailyInterval,
                weekdays: $weekdays,
                timesPerWeek: $timesPerWeek,
                monthDays: $monthDays,
                startPolicy: $startPolicy
            )

            Section {
                Toggle(L10n.t("wizard.set_end"), isOn: $hasEndDay)
                if hasEndDay {
                    DatePicker(
                        L10n.t("wizard.ends_on"),
                        selection: $recurrenceEndDate,
                        in: calendar.displayDate(of: store.today)...,
                        displayedComponents: .date
                    )
                }
            } header: {
                Text(L10n.t("wizard.until_when"))
            } footer: {
                Text(L10n.t("wizard.no_end"))
            }
        } else {
            Section {
                DatePicker(
                    L10n.t("wizard.start_date"),
                    selection: $startDate,
                    in: calendar.displayDate(of: store.today)...,
                    displayedComponents: .date
                )
                DatePicker(
                    L10n.t("wizard.end_date"),
                    selection: $endDate,
                    in: startDate...,
                    displayedComponents: .date
                )
                DatePicker(L10n.t("wizard.due_on_end"), selection: $dueTime, displayedComponents: .hourAndMinute)
            } header: {
                Text(L10n.t("wizard.range_section"))
            } footer: {
                Text(L10n.t("wizard.range_footer"))
            }
        }
    }

    private var rewardPreview: some View {
        let day = previewScheduledDay
        let engine = RewardEngine(config: store.container.config)
        let context = RewardContext(
            difficulty: difficulty,
            priority: priority,
            estimatedMinutes: estimatedMinutes,
            isPlannedAhead: isLongTerm || day > store.today,
            scheduledDay: day,
            completedDay: day,
            dueAt: previewDueAt,
            completedAt: previewDueAt.addingTimeInterval(-60),
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
                    .foregroundStyle(goldTint)
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
        }
    }

    private var previewScheduledDay: GameDay {
        if boardKind == .side { return store.today }
        if isLongTerm, longTermMode == .recurrence {
            return startPolicy == .thisPeriod ? store.today : calendar.adding(days: 1, to: store.today)
        }
        return calendar.gameDay(fromDisplayDate: startDate)
    }

    private var previewDueAt: Date {
        if isLongTerm, longTermMode == .dateRange {
            return calendar.date(on: calendar.gameDay(fromDisplayDate: endDate), matchingTimeOf: dueTime)
        }
        return calendar.date(on: previewScheduledDay, matchingTimeOf: dueTime)
    }

    // MARK: - 动作

    private func wizardQuestion(eyebrow: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow)
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.accent)
            Text(title)
                .font(.title2.weight(.bold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var difficultyRewardText: String {
        let exp = Int(store.container.config.balance.baseEXP(for: difficulty).rounded())
        let gold = Int((Double(exp) * store.container.config.balance.goldRatio).rounded())
        return L10n.format("wizard.base_reward", exp, gold)
    }

    private func bootstrap() {
        guard !didLoad else { return }
        didLoad = true
        dueTime = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: Date()) ?? Date()
        if let initialBoardKind {
            boardKind = initialBoardKind
            if initialBoardKind == .side {
                prepareDetails()
                step = .details
            } else {
                step = .mainKind
            }
        }
    }

    private func prepareDetails() {
        if boardKind == .side {
            startDate = calendar.displayDate(of: store.today)
        } else if mainKind == .urgent {
            startDate = calendar.displayDate(of: calendar.adding(days: 1, to: store.today))
        } else {
            startDate = calendar.displayDate(of: calendar.adding(days: 1, to: store.today))
            endDate = calendar.displayDate(of: calendar.adding(days: 7, to: store.today))
            recurrenceEndDate = endDate
        }
        if shares.isEmpty {
            shares = SkillShareMath.equalShares(ids: store.skills.map(\.id))
        }
    }

    private func goBack() {
        switch step {
        case .boardKind:
            dismiss()
        case .mainKind:
            step = .boardKind
        case .details:
            if boardKind == .side {
                if initialBoardKind == .side {
                    dismiss()
                } else {
                    step = .boardKind
                }
            } else {
                step = .mainKind
            }
        }
    }

    private func publish() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let skillShares = shares.asSkillShares

        if isLongTerm, longTermMode == .recurrence {
            let recurrence = RecurrenceEditor.rule(
                mode: recurrenceMode,
                dailyInterval: dailyInterval,
                weekdays: weekdays,
                timesPerWeek: timesPerWeek,
                monthDays: monthDays
            )
            store.createTemplate(
                title: trimmed,
                detail: detail,
                difficulty: difficulty,
                priority: priority,
                estimatedMinutes: estimatedMinutes,
                recurrence: recurrence,
                startPolicy: startPolicy,
                skillShares: skillShares,
                startDay: store.today,
                endDay: hasEndDay ? calendar.gameDay(fromDisplayDate: recurrenceEndDate) : nil
            )
        } else if isLongTerm, longTermMode == .dateRange {
            let startDay = calendar.gameDay(fromDisplayDate: startDate)
            let endDay = max(startDay, calendar.gameDay(fromDisplayDate: endDate))
            store.createQuest(
                title: trimmed,
                detail: detail,
                difficulty: difficulty,
                priority: priority,
                estimatedMinutes: estimatedMinutes,
                scheduledDay: startDay,
                dueAt: calendar.date(on: endDay, matchingTimeOf: dueTime),
                skillShares: skillShares,
                preferredKind: .main
            )
        } else {
            let day = boardKind == .side ? store.today : calendar.gameDay(fromDisplayDate: startDate)
            store.createQuest(
                title: trimmed,
                detail: detail,
                difficulty: difficulty,
                priority: priority,
                estimatedMinutes: estimatedMinutes,
                scheduledDay: day,
                dueAt: calendar.date(on: day, matchingTimeOf: dueTime),
                skillShares: skillShares,
                preferredKind: boardKind == .side ? .side : .main
            )
        }
        dismiss()
    }
}

struct QuestPublishLaunch: Identifiable {
    let id = UUID()
    var boardKind: QuestPublishWizardView.BoardKind?
}
