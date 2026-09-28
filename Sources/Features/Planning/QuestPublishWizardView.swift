import SwiftUI

/// 工会接待处。主线仍走「栏位 → 形态 → 细节」；支线只填标题，回车即可张贴。
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
    @State private var estimatedMinutes = 30
    @State private var priority: QuestPriority = .normal
    @State private var selectedSkillIDs: Set<UUID> = []
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
    @State private var maxCompletionsPerDay = 1

    @State private var didLoad = false
    @FocusState private var titleFocused: Bool

    private var calendar: GameCalendar { store.container.calendar }
    private var goldTint: Color { Color(hex: "#D4A017") }

    private var isLongTerm: Bool {
        boardKind == .main && mainKind == .recurring
    }

    private var canPublish: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var skillShares: [SkillShare] {
        SkillShareMath.selected(store.skills.map(\.id).filter { selectedSkillIDs.contains($0) }).asSkillShares
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
                    if boardKind == .side {
                        sideComposer
                    } else {
                        detailsStep
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !store.isTutorialActive {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(step == .boardKind ? L10n.t("wizard.cancel") : L10n.t("common.back"), action: goBack)
                    }
                }
                if step == .details {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.t("wizard.post"), action: publish)
                            .disabled(!canPublish)
                    }
                }
            }
            .onAppear(perform: bootstrap)
            .onChange(of: store.tutorialStep) { _, step in
                applyTutorial(step)
            }
            .interactiveDismissDisabled(store.isTutorialActive)
            .tutorialCoach(host: .wizard)
        }
    }

    private var navigationTitle: String {
        switch step {
        case .boardKind: return L10n.t("wizard.title.publish")
        case .mainKind: return L10n.t("wizard.title.main_kind")
        case .details:
            if boardKind == .side { return L10n.t("wizard.title.side") }
            return isLongTerm ? L10n.t("wizard.title.repeat") : L10n.t("wizard.title.details")
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
                .tutorialAnchor(.wizardMain)

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
                .tutorialAnchor(.wizardSide)
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
                .tutorialAnchor(.wizardUrgent)
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - 支线：标题 + 回车

    private var sideComposer: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(L10n.t("wizard.hint.side"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    TextField(L10n.t("wizard.side.placeholder"), text: $title)
                        .textFieldStyle(.plain)
                        .font(.title3.weight(.medium))
                        .submitLabel(.go)
                        .focused($titleFocused)
                        .onSubmit(publish)

                    Button(action: publish) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title)
                            .foregroundStyle(canPublish ? Color.orange : Color.secondary.opacity(0.35))
                    }
                    .disabled(!canPublish)
                    .accessibilityLabel(L10n.t("wizard.post"))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )

                if !store.skills.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.t("wizard.skill_pick"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        SkillPickList(skills: store.skills, selectedIDs: $selectedSkillIDs)
                    }
                }

                rewardPreview
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear { titleFocused = true }
    }

    // MARK: - C / D. 主线细节

    private var detailsStep: some View {
        Form {
            Section {
                Text(detailsEyebrow)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.accent)
                TextField(L10n.t("wizard.field.title"), text: $title)
                TextField(L10n.t("wizard.field.detail"), text: $detail, axis: .vertical)
                    .lineLimit(1...4)
                QuestChallengeFields(estimatedMinutes: $estimatedMinutes, priority: $priority)
            } header: {
                Text(L10n.t("wizard.notice"))
            } footer: {
                Text(L10n.t("quest.difficulty.auto_footer"))
            }

            Section {
                SkillPickList(skills: store.skills, selectedIDs: $selectedSkillIDs)
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
            DatePicker(
                L10n.t("wizard.start_date"),
                selection: $startDate,
                in: calendar.displayDate(of: store.today)...,
                displayedComponents: .date
            )
            DatePicker(L10n.t("wizard.due_time"), selection: $dueTime, displayedComponents: .hourAndMinute)
        } header: {
            Text(L10n.t("wizard.schedule"))
        } footer: {
            Text(oneShotFooter)
        }
    }

    private var oneShotFooter: String {
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
                startPolicy: $startPolicy,
                maxCompletionsPerDay: $maxCompletionsPerDay
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
            difficulty: .fromEstimatedMinutes(estimatedMinutes),
            priority: priority,
            estimatedMinutes: estimatedMinutes,
            isPlannedAhead: isLongTerm || day > store.today,
            scheduledDay: day,
            completedDay: day,
            dueAt: previewDueAt,
            completedAt: previewDueAt.addingTimeInterval(-60),
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
        applyTutorial(store.tutorialStep)
    }

    private func applyTutorial(_ tutorial: TutorialStep?) {
        guard store.isTutorialActive, let tutorial else { return }
        switch tutorial {
        case .pickUrgent:
            boardKind = .main
            step = .mainKind
        case .fillMain:
            boardKind = .main
            mainKind = .urgent
            prepareDetails()
            step = .details
        case .fillSide:
            boardKind = .side
            prepareDetails()
            step = .details
        default:
            break
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
                difficulty: .fromEstimatedMinutes(estimatedMinutes),
                priority: priority,
                estimatedMinutes: estimatedMinutes,
                recurrence: recurrence,
                startPolicy: startPolicy,
                skillShares: skillShares,
                startDay: store.today,
                endDay: hasEndDay ? calendar.gameDay(fromDisplayDate: recurrenceEndDate) : nil,
                maxCompletionsPerDay: maxCompletionsPerDay
            )
        } else if isLongTerm, longTermMode == .dateRange {
            let startDay = calendar.gameDay(fromDisplayDate: startDate)
            let endDay = max(startDay, calendar.gameDay(fromDisplayDate: endDate))
            store.createQuest(
                title: trimmed,
                detail: detail,
                difficulty: .fromEstimatedMinutes(estimatedMinutes),
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
                difficulty: .fromEstimatedMinutes(estimatedMinutes),
                priority: boardKind == .side ? .normal : priority,
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
