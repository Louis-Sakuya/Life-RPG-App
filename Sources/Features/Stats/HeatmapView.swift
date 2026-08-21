import SwiftUI

/// GitHub 风格的贡献热力图。每一列是一周，从周一到周日自上而下。
struct HeatmapView: View {
    @Environment(\.palette) private var palette

    var points: [StatsPoint]
    var cellSize: CGFloat = 11
    var spacing: CGFloat = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(columns.indices, id: \.self) { index in
                        VStack(spacing: spacing) {
                            ForEach(0..<7, id: \.self) { row in
                                cell(for: columns[index][row])
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            HStack(spacing: 6) {
                Text(L10n.t("stats.less"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                ForEach(0...4, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(color(for: level))
                        .frame(width: cellSize, height: cellSize)
                }
                Text(L10n.t("stats.more"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// 把连续的日序列切成周列。首列用 nil 补齐，保证每一行对应固定的星期。
    private var columns: [[StatsPoint?]] {
        guard let first = points.first else { return [] }
        let leadingPadding = weekdayIndex(of: first.day)

        var flat: [StatsPoint?] = Array(repeating: nil, count: leadingPadding)
        flat.append(contentsOf: points.map { Optional($0) })
        while flat.count % 7 != 0 {
            flat.append(nil)
        }

        return stride(from: 0, to: flat.count, by: 7).map { start in
            Array(flat[start..<min(start + 7, flat.count)])
        }
    }

    private func cell(for point: StatsPoint?) -> some View {
        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
            .fill(point == nil ? Color.clear : color(for: point?.heatLevel ?? 0))
            .frame(width: cellSize, height: cellSize)
    }

    private func color(for level: Int) -> Color {
        switch level {
        case 0: return Color.primary.opacity(0.07)
        case 1: return palette.accent.opacity(0.28)
        case 2: return palette.accent.opacity(0.5)
        case 3: return palette.accent.opacity(0.74)
        default: return palette.accent
        }
    }

    /// 0 = 周一 ... 6 = 周日
    private func weekdayIndex(of day: GameDay) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        let date = calendar.date(from: day.dateComponents) ?? Date()
        let weekday = calendar.component(.weekday, from: date)
        return (weekday + 5) % 7
    }
}
