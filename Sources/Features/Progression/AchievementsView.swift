import SwiftUI

/// 成就与称号共用同一套规则数据与同一个界面，只是 `kind` 不同。
struct AchievementsView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette

    var kind: UnlockKind

    var body: some View {
        List {
            let entries = store.ruleProgress(kind: kind)
            let unlocked = entries.filter(\.isUnlocked)
            let locked = entries.filter { !$0.isUnlocked }

            Section {
                HStack {
                    Text("已解锁")
                    Spacer()
                    Text("\(unlocked.count) / \(entries.count)")
                        .foregroundStyle(.secondary)
                }
                ProgressBar(
                    value: entries.isEmpty ? 0 : Double(unlocked.count) / Double(entries.count),
                    gradient: palette.gradient,
                    height: 8
                )
                .padding(.vertical, 4)
            }

            if !unlocked.isEmpty {
                Section("已获得") {
                    ForEach(unlocked, id: \.rule.id) { entry in
                        UnlockRow(rule: entry.rule, progress: 1, text: entry.text, isUnlocked: true)
                    }
                }
            }

            if !locked.isEmpty {
                Section("未解锁") {
                    ForEach(locked, id: \.rule.id) { entry in
                        UnlockRow(rule: entry.rule, progress: entry.progress, text: entry.text, isUnlocked: false)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(kind.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.markUnlocksSeen()
        }
    }
}

struct UnlockRow: View {
    @Environment(\.palette) private var palette

    var rule: UnlockRule
    var progress: Double
    var text: String?
    var isUnlocked: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? palette.accent.opacity(0.9) : Color.primary.opacity(0.08))
                    .frame(width: 38, height: 38)
                Image(systemName: rule.icon)
                    .foregroundStyle(isUnlocked ? .white : Color.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(rule.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(isUnlocked ? Color.primary : Color.secondary)
                if !rule.detail.isEmpty {
                    Text(rule.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !isUnlocked && progress > 0 {
                    ProgressBar(value: progress, gradient: palette.gradient, height: 5)
                    if let text {
                        Text(text)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)

            if !rule.reward.isEmpty {
                VStack(alignment: .trailing, spacing: 2) {
                    if rule.reward.exp > 0 {
                        Text("+\(rule.reward.exp) EXP")
                            .font(.caption2)
                            .foregroundStyle(palette.accent)
                    }
                    if rule.reward.gold > 0 {
                        Text("+\(rule.reward.gold) G")
                            .font(.caption2)
                            .foregroundStyle(Color(hex: "#D4A017"))
                    }
                }
            }
        }
        .padding(.vertical, 3)
    }
}
