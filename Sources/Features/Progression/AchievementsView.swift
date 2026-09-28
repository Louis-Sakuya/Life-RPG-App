import SwiftUI

/// 成就与称号共用同一套规则数据，详情页按「已完成 / 进行中」两段卡片展示。
struct AchievementsView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette

    var kind: UnlockKind

    var body: some View {
        let entries = store.ruleProgress(kind: kind)
        let unlocked = entries.filter(\.isUnlocked)
        let locked = entries.filter { !$0.isUnlocked }.sorted { $0.progress > $1.progress }

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HonorSurface {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(L10n.t("unlock.unlocked"))
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(unlocked.count) / \(entries.count)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        ProgressBar(
                            value: entries.isEmpty ? 0 : Double(unlocked.count) / Double(entries.count),
                            gradient: palette.gradient,
                            height: 8
                        )
                    }
                }

                if !unlocked.isEmpty {
                    honorSectionTitle(L10n.t("unlock.obtained"))
                    ForEach(unlocked, id: \.rule.id) { entry in
                        UnlockRow(rule: entry.rule, progress: 1, text: entry.text, isUnlocked: true)
                    }
                }

                if !locked.isEmpty {
                    honorSectionTitle(L10n.t("unlock.locked"))
                    ForEach(locked, id: \.rule.id) { entry in
                        UnlockRow(rule: entry.rule, progress: entry.progress, text: entry.text, isUnlocked: false)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background { AtmosphereCanvas() }
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

    private var goldTint: Color { Color(hex: "#D4A017") }

    var body: some View {
        HonorSurface {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isUnlocked ? palette.accent.opacity(0.22) : Color.primary.opacity(0.06))
                        .frame(width: 44, height: 44)
                    Image(systemName: rule.icon)
                        .foregroundStyle(isUnlocked ? palette.accent : Color.secondary)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(rule.localizedName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isUnlocked ? goldTint : Color.secondary)
                    if !rule.localizedDetail.isEmpty {
                        Text(rule.localizedDetail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !isUnlocked {
                        ProgressBar(value: progress, gradient: palette.gradient, height: 6)
                        if let text {
                            Text(text)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer(minLength: 8)

                if isUnlocked {
                    Image(systemName: "sparkle")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(goldTint)
                        .padding(.top, 4)
                }
            }
        }
        .opacity(isUnlocked ? 1 : 0.88)
    }
}

func honorSectionTitle(_ title: String) -> some View {
    Text(title)
        .font(.title3.weight(.bold))
        .padding(.top, 4)
}
