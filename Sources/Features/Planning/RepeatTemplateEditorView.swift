import SwiftUI

struct RepeatTemplateEditorView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private enum RecurrenceMode: String, CaseIterable, Identifiable {
        case daily, weekly, timesPerWeek, monthly
        var id: String { rawValue }
        var title: String {
            switch self {
            case .daily: return "每天"
            case .weekly: return "每周指定"
            case .timesPerWeek: return "每周若干次"
            case .monthly: return "每月"
            }
        }
    }

    @State private var title = ""
    @State private var detail = ""
    @State private var difficulty: QuestDifficulty = .normal
    @State private var priority: QuestPriority = .normal
    @State private var estimatedMinutes = 30
    @State private var mode: RecurrenceMode = .daily
    @State private var dailyInterval = 1
    @State private var weekdays: Set<Int> = [2, 4, 6]
    @State private var timesPerWeek = 3
    @State private var monthDays: Set<Int> = [1]
    @State private var startPolicy: RecurrenceStartPolicy = .thisPeriod
    @State private var shares: [UUID: Double] = [:]

    private static let weekdayNames = ["日", "一", "二", "三", "四", "五", "六"]

    var body: some View {
        NavigationStack {
            Form {
                Section("基本") {
                    TextField("任务标题", text: $title)
                    TextField("描述（可选）", text: $detail, axis: .vertical)
                        .lineLimit(1...3)
                    Picker("难度", selection: $difficulty) {
                        ForEach(QuestDifficulty.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("优先级", selection: $priority) {
                        ForEach(QuestPriority.allCases) { Text($0.title).tag($0) }
                    }
                    Stepper("预计时长 \(estimatedMinutes) 分钟", value: $estimatedMinutes, in: 5...600, step: 5)
                }

                Section("重复规律") {
                    Picker("方式", selection: $mode) {
                        ForEach(RecurrenceMode.allCases) { Text($0.title).tag($0) }
                    }

                    switch mode {
                    case .daily:
                        Stepper("每 \(dailyInterval) 天一次", value: $dailyInterval, in: 1...30)
                    case .weekly:
                        weekdayPicker
                    case .timesPerWeek:
                        Stepper("每周 \(timesPerWeek) 次", value: $timesPerWeek, in: 1...7)
                    case .monthly:
                        monthDayPicker
                    }
                }

                Section {
                    Picker("起算", selection: $startPolicy) {
                        ForEach(RecurrenceStartPolicy.allCases, id: \.self) { policy in
                            Text(policyTitle(policy)).tag(policy)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("起算周期")
                } footer: {
                    Text("选择从下一周期开始，可以避免本周的进度被半途开始的记录拉低。")
                }

                Section("技能经验分配") {
                    SkillShareEditor(skills: store.skills, shares: $shares)
                }

                Section {
                    ForEach(store.templates()) { template in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(template.title)
                            Text(template.recurrence.displayText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { offsets in
                        let templates = store.templates()
                        for index in offsets {
                            store.deleteTemplate(templates[index])
                        }
                    }
                } header: {
                    Text("已有的周期任务")
                }
            }
            .navigationTitle("周期任务")
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
        }
    }

    private var weekdayPicker: some View {
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { index in
                Button {
                    if weekdays.contains(index) {
                        weekdays.remove(index)
                    } else {
                        weekdays.insert(index)
                    }
                } label: {
                    Text(Self.weekdayNames[index - 1])
                        .font(.subheadline)
                        .frame(width: 34, height: 34)
                        .background(
                            Circle().fill(weekdays.contains(index) ? Color.accentColor.opacity(0.25) : Color.primary.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var monthDayPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(1...31, id: \.self) { day in
                    Button {
                        if monthDays.contains(day) {
                            monthDays.remove(day)
                        } else {
                            monthDays.insert(day)
                        }
                    } label: {
                        Text("\(day)")
                            .font(.caption)
                            .frame(width: 30, height: 30)
                            .background(
                                Circle().fill(monthDays.contains(day) ? Color.accentColor.opacity(0.25) : Color.primary.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func policyTitle(_ policy: RecurrenceStartPolicy) -> String {
        switch mode {
        case .monthly:
            return policy == .thisPeriod ? "从本月开始" : "从下月开始"
        case .daily:
            return policy == .thisPeriod ? "从今天开始" : "从明天开始"
        case .weekly, .timesPerWeek:
            return policy.title
        }
    }

    private var recurrence: RecurrenceRule {
        switch mode {
        case .daily: return .daily(interval: dailyInterval)
        case .weekly: return .weekly(weekdays: Array(weekdays))
        case .timesPerWeek: return .timesPerWeek(count: timesPerWeek)
        case .monthly: return .monthly(days: Array(monthDays))
        }
    }

    private func save() {
        store.createTemplate(
            title: title,
            detail: detail,
            difficulty: difficulty,
            priority: priority,
            estimatedMinutes: estimatedMinutes,
            recurrence: recurrence,
            startPolicy: startPolicy,
            skillShares: shares.asSkillShares
        )
        dismiss()
    }
}
