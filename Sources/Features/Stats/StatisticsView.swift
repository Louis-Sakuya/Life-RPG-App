import SwiftUI
import Charts

struct StatisticsView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette

    @State private var range: StatsRange = .week
    @State private var selectedSkillID: UUID?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppMetrics.sectionSpacing) {
                    rangePicker
                    overviewCard
                    trendCard
                    compositionCard
                    skillGrowthCard
                    heatmapCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background { AtmosphereCanvas() }
            .navigationTitle(L10n.t("stats.title"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var summary: StatsSummary {
        store.container.statistics.summary(for: range, today: store.today)
    }

    private var rangePicker: some View {
        Picker(L10n.t("stats.range"), selection: $range) {
            ForEach(StatsRange.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
    }

    private var overviewCard: some View {
        let summary = self.summary
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(L10n.t("stats.overview"), subtitle: "\(summary.startDay.shortLabel) - \(summary.endDay.shortLabel)")

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    metric(L10n.t("stats.completion"), String(format: "%.0f%%", summary.completionRate * 100), "chart.pie.fill", palette.accent)
                    metric(L10n.t("stats.quests_done"), "\(summary.questsCompleted)", "checkmark.circle.fill", .green)
                    metric(L10n.t("stats.habit_checkins"), "\(summary.habitCheckIns)", "repeat.circle.fill", .teal)
                    metric(L10n.t("stats.exp_earned"), "\(summary.expEarned)", "sparkles", palette.secondary)
                    metric(L10n.t("stats.gold_earned"), "\(summary.goldEarned)", "dollarsign.circle.fill", Color(hex: "#D4A017"))
                    metric(L10n.t("stats.active_days"), "\(summary.activeDays)", "flame.fill", .orange)
                }

                if let hours = summary.averageTurnaroundHours {
                    Text(L10n.format("stats.avg_hours", hours))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var trendCard: some View {
        let points = summary.points
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(L10n.t("stats.daily_gain"), subtitle: L10n.t("stats.daily_gain_sub"))
                if points.isEmpty {
                    Text(L10n.t("stats.no_data"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Chart {
                        ForEach(points) { point in
                            BarMark(
                                x: .value(L10n.t("stats.chart.date"), point.day.shortLabel),
                                y: .value("EXP", point.exp)
                            )
                            .foregroundStyle(palette.accent)
                        }
                    }
                    .frame(height: 160)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 6))
                    }
                }
            }
        }
    }

    private var compositionCard: some View {
        let summary = self.summary
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(L10n.t("stats.main_side"), subtitle: L10n.t("stats.main_side_sub"))

                ProgressBar(
                    value: summary.mainRatio,
                    gradient: LinearGradient(colors: [palette.accent, .orange], startPoint: .leading, endPoint: .trailing),
                    height: 12
                )

                HStack {
                    Label(L10n.format("stats.main_count", summary.mainQuestsCompleted), systemImage: "flag.fill")
                        .font(.caption)
                        .foregroundStyle(palette.accent)
                    Spacer()
                    Label(L10n.format("stats.side_count", summary.sideQuestsCompleted), systemImage: "bolt.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Text(compositionHint(ratio: summary.mainRatio))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var skillGrowthCard: some View {
        let skills = store.skills
        let selected = selectedSkillID ?? skills.first?.id
        let bounds = store.container.statistics.range(range == .day ? .month : range, endingAt: store.today)

        return Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(L10n.t("stats.skill_curve"))

                if skills.isEmpty {
                    Text(L10n.t("stats.no_skills"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Picker(L10n.t("stats.skill"), selection: Binding(
                        get: { selected },
                        set: { selectedSkillID = $0 }
                    )) {
                        ForEach(skills) { skill in
                            Text(skill.localizedName).tag(Optional(skill.id))
                        }
                    }
                    .pickerStyle(.menu)

                    if let selected {
                        let series = store.container.statistics.skillGrowth(skillID: selected, in: bounds)
                        let tint = skills.first { $0.id == selected }.map { Color(hex: $0.colorHex) } ?? palette.accent
                        Chart {
                            ForEach(series, id: \.day.value) { entry in
                                LineMark(
                                    x: .value(L10n.t("stats.chart.date"), entry.day.shortLabel),
                                    y: .value(L10n.t("stats.level"), entry.level)
                                )
                                .foregroundStyle(tint)
                                .interpolationMethod(.monotone)
                            }
                        }
                        .frame(height: 150)
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 5))
                        }
                    }
                }
            }
        }
    }

    private var heatmapCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(L10n.t("stats.heatmap"), subtitle: L10n.t("stats.heatmap_sub"))
                HeatmapView(points: store.container.statistics.heatmap(days: 182, endingAt: store.today))
            }
        }
    }

    private func metric(_ title: String, _ value: String, _ icon: String, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.10))
        )
    }

    private func compositionHint(ratio: Double) -> String {
        if ratio >= 0.6 {
            return L10n.t("stats.mix.healthy")
        }
        if ratio >= 0.3 {
            return L10n.t("stats.mix.mixed")
        }
        return L10n.t("stats.mix.side")
    }
}
