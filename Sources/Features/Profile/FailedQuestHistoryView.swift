import SwiftUI

struct FailedQuestHistoryView: View {
    @Environment(GameStore.self) private var store

    private var records: [FailedQuestRecord] {
        store.failedQuestRecords()
    }

    var body: some View {
        List {
            if records.isEmpty {
                EmptyStateView(
                    icon: "tray",
                    title: L10n.t("fail.history.empty_title"),
                    message: L10n.t("fail.history.empty")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(records, id: \.id) { record in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(record.title)
                            .font(.body.weight(.semibold))
                        if !record.detail.isEmpty {
                            Text(record.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        HStack(spacing: 6) {
                            StatPill(
                                icon: "calendar",
                                text: scheduleText(record),
                                tint: .secondary
                            )
                            StatPill(
                                icon: "chart.bar",
                                text: L10n.format("fail.history.progress", record.progressDone, record.progressTarget),
                                tint: .orange
                            )
                        }
                        Text(L10n.format("fail.history.failed_at", record.failedDay.shortLabel))
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(L10n.t("fail.history.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func scheduleText(_ record: FailedQuestRecord) -> String {
        if record.scheduledStart == record.scheduledEnd {
            return record.scheduledStart.shortLabel
        }
        return L10n.format(
            "fail.history.period",
            record.scheduledStart.shortLabel,
            record.scheduledEnd.shortLabel
        )
    }
}
