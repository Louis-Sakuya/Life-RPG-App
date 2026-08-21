import SwiftUI

/// 奖励流水。让"我的经验和金币是怎么来的"完全可追溯，
/// 这也是撤销完成时能精确回滚的底层依据。
struct LedgerView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette

    var body: some View {
        List {
            let transactions = RecordRepository(context: store.container.context).recentTransactions(limit: 200)

            if transactions.isEmpty {
                Text(L10n.t("ledger.empty"))
                    .foregroundStyle(.secondary)
            }

            ForEach(transactions) { transaction in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(transaction.sourceTitle)
                            .font(.body.weight(.medium))
                            .strikethrough(transaction.isReverted)
                        Spacer()
                        Text(deltaText(transaction))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(transaction.goldDelta < 0 ? Color.red : palette.accent)
                    }
                    HStack(spacing: 6) {
                        StatPill(icon: "tag.fill", text: transaction.sourceKind.displayName, tint: .secondary)
                        Text(transaction.day.description)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if transaction.isReverted {
                            StatPill(icon: "arrow.uturn.backward", text: L10n.t("ledger.reverted"), tint: .red)
                        }
                    }
                    if !transaction.breakdown.isEmpty {
                        Text(transaction.breakdown)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .listStyle(.plain)
        .navigationTitle(L10n.t("ledger.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func deltaText(_ transaction: RewardTransaction) -> String {
        var parts: [String] = []
        if transaction.expDelta != 0 {
            parts.append("\(transaction.expDelta > 0 ? "+" : "")\(transaction.expDelta) EXP")
        }
        if transaction.goldDelta != 0 {
            parts.append("\(transaction.goldDelta > 0 ? "+" : "")\(transaction.goldDelta) G")
        }
        return parts.joined(separator: " · ")
    }
}
