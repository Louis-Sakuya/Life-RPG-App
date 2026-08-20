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
            .background(Color(.systemGroupedBackground))
            .navigationTitle("统计")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var summary: StatsSummary {
        store.container.statistics.summary(for: range, today: store.today)
    }

    private var rangePicker: some View {
        Picker("范围", selection: $range) {
            ForEach(StatsRange.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
    }

    private var overviewCard: some View {
        let summary = self.summary
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("概览", subtitle: "\(summary.startDay.shortLabel) - \(summary.endDay.shortLabel)")

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    metric("完成率", String(format: "%.0f%%", summary.completionRate * 100), "chart.pie.fill", palette.accent)
                    metric("完成任务", "\(summary.questsCompleted)", "checkmark.circle.fill", .green)
                    metric("习惯打卡", "\(summary.habitCheckIns)", "repeat.circle.fill", .teal)
                    metric("获得 EXP", "\(summary.expEarned)", "sparkles", palette.secondary)
                    metric("获得 Gold", "\(summary.goldEarned)", "dollarsign.circle.fill", Color(hex: "#D4A017"))
                    metric("活跃天数", "\(summary.activeDays)", "flame.fill", .orange)
                }

                if let hours = summary.averageTurnaroundHours {
                    Text(String(format: "任务从创建到完成平均耗时 %.1f 小时", hours))
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
                SectionHeader("每日获得", subtitle: "经验与金币的产出节奏")
                if points.isEmpty {
                    Text("这个区间还没有数据")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Chart {
                        ForEach(points) { point in
                            BarMark(
                                x: .value("日期", point.day.shortLabel),
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
                SectionHeader("主线与支线", subtitle: "规划带来的结构变化")

                ProgressBar(
                    value: summary.mainRatio,
                    gradient: LinearGradient(colors: [palette.accent, .orange], startPoint: .leading, endPoint: .trailing),
                    height: 12
                )

                HStack {
                    Label("主线 \(summary.mainQuestsCompleted)", systemImage: "flag.fill")
                        .font(.caption)
                        .foregroundStyle(palette.accent)
                    Spacer()
                    Label("支线 \(summary.sideQuestsCompleted)", systemImage: "bolt.fill")
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
                SectionHeader("技能成长曲线")

                if skills.isEmpty {
                    Text("还没有技能")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Picker("技能", selection: Binding(
                        get: { selected },
                        set: { selectedSkillID = $0 }
                    )) {
                        ForEach(skills) { skill in
                            Text(skill.name).tag(Optional(skill.id))
                        }
                    }
                    .pickerStyle(.menu)

                    if let selected {
                        let series = store.container.statistics.skillGrowth(skillID: selected, in: bounds)
                        let tint = skills.first { $0.id == selected }.map { Color(hex: $0.colorHex) } ?? palette.accent
                        Chart {
                            ForEach(series, id: \.day.value) { entry in
                                LineMark(
                                    x: .value("日期", entry.day.shortLabel),
                                    y: .value("等级", entry.level)
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
                SectionHeader("完成热力图", subtitle: "最近 26 周")
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
            return "大部分产出来自提前规划的主线，节奏很健康。"
        }
        if ratio >= 0.3 {
            return "主线与支线各占一半，试着把更多事情提前一天安排。"
        }
        return "几乎全是当天临时任务，奖励被打了五折。规划一下明天会立刻见效。"
    }
}
