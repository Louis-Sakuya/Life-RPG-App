import SwiftUI

enum RecurrenceMode: String, CaseIterable, Identifiable {
    case daily, weekly, timesPerWeek, monthly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: return L10n.t("recurrence.daily")
        case .weekly: return L10n.t("recurrence.weekly")
        case .timesPerWeek: return L10n.t("recurrence.times_per_week")
        case .monthly: return L10n.t("recurrence.monthly")
        }
    }
}

/// 周期规律编辑。发布向导与周期模板编辑器共用，避免两套选择器漂移。
struct RecurrenceEditor: View {
    @Binding var mode: RecurrenceMode
    @Binding var dailyInterval: Int
    @Binding var weekdays: Set<Int>
    @Binding var timesPerWeek: Int
    @Binding var monthDays: Set<Int>
    @Binding var startPolicy: RecurrenceStartPolicy

    var recurrence: RecurrenceRule {
        Self.rule(
            mode: mode,
            dailyInterval: dailyInterval,
            weekdays: weekdays,
            timesPerWeek: timesPerWeek,
            monthDays: monthDays
        )
    }

    static func rule(
        mode: RecurrenceMode,
        dailyInterval: Int,
        weekdays: Set<Int>,
        timesPerWeek: Int,
        monthDays: Set<Int>
    ) -> RecurrenceRule {
        switch mode {
        case .daily: return .daily(interval: dailyInterval)
        case .weekly: return .weekly(weekdays: Array(weekdays))
        case .timesPerWeek: return .timesPerWeek(count: timesPerWeek)
        case .monthly: return .monthly(days: Array(monthDays))
        }
    }

    var body: some View {
        Group {
        Section(L10n.t("recurrence.section")) {
            Picker(L10n.t("recurrence.mode"), selection: $mode) {
                ForEach(RecurrenceMode.allCases) { Text($0.title).tag($0) }
            }

            switch mode {
            case .daily:
                Stepper(L10n.format("recurrence.every_n_stepper", dailyInterval), value: $dailyInterval, in: 1...30)
            case .weekly:
                weekdayPicker
            case .timesPerWeek:
                Stepper(L10n.format("recurrence.times_stepper", timesPerWeek), value: $timesPerWeek, in: 1...7)
            case .monthly:
                monthDayPicker
            }
        }

        Section {
            Picker(L10n.t("recurrence.start"), selection: $startPolicy) {
                ForEach(RecurrenceStartPolicy.allCases, id: \.self) { policy in
                    Text(policyTitle(policy)).tag(policy)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text(L10n.t("recurrence.start_period"))
        } footer: {
            Text(L10n.t("recurrence.start_footer"))
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
                    Text(L10n.weekdayShort(index))
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
            return policy == .thisPeriod ? L10n.t("recurrence.this_month") : L10n.t("recurrence.next_month")
        case .daily:
            return policy == .thisPeriod ? L10n.t("recurrence.from_today") : L10n.t("recurrence.from_tomorrow")
        case .weekly, .timesPerWeek:
            return policy.title
        }
    }
}
