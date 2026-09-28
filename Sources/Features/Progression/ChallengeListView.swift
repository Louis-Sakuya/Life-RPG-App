import SwiftUI

/// 挑战列表。进度不存库，而是每次由 `UnlockEngine` 用当前统计量算出来，
/// 因此永远不会出现"进度条和真实数据对不上"的情况。
struct ChallengeListView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette

    @State private var isPresentingEditor = false

    var body: some View {
        let entries = store.challengeProgress()
        let ongoing = entries.filter { !$0.challenge.isCompleted }.sorted { $0.progress > $1.progress }
        let finished = entries.filter { $0.challenge.isCompleted }

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                honorSectionTitle(L10n.t("challenge.ongoing"))
                if ongoing.isEmpty {
                    Text(L10n.t("challenge.none"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(ongoing, id: \.challenge.id) { entry in
                        ChallengeRow(challenge: entry.challenge, progress: entry.progress, text: entry.text)
                    }
                }

                Text(L10n.t("challenge.footer"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                if !finished.isEmpty {
                    honorSectionTitle(L10n.t("challenge.completed"))
                    ForEach(finished, id: \.challenge.id) { entry in
                        ChallengeRow(challenge: entry.challenge, progress: 1, text: entry.text)
                    }
                }

                Button {
                    isPresentingEditor = true
                } label: {
                    HonorSurface {
                        Label(L10n.t("challenge.custom"), systemImage: "plus.circle")
                            .foregroundStyle(palette.accent)
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background { AtmosphereCanvas() }
        .sheet(isPresented: $isPresentingEditor) {
            ChallengeEditorView()
        }
    }
}

struct ChallengeRow: View {
    @Environment(\.palette) private var palette

    var challenge: Challenge
    var progress: Double
    var text: String?

    private var goldTint: Color { Color(hex: "#D4A017") }

    var body: some View {
        HonorSurface {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(palette.accent.opacity(challenge.isCompleted ? 0.22 : 0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: challenge.isCompleted ? "sparkle" : challenge.iconName)
                        .foregroundStyle(challenge.isCompleted ? goldTint : palette.accent)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(challenge.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(challenge.isCompleted ? goldTint : Color.primary)
                    if !challenge.detail.isEmpty {
                        Text(challenge.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !challenge.isCompleted {
                        ProgressBar(value: progress, gradient: palette.gradient, height: 6)
                    }
                    HStack {
                        if let text, !challenge.isCompleted {
                            Text(text)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if challenge.rewardEXP > 0 || challenge.rewardGold > 0 {
                            Text("+\(challenge.rewardEXP) EXP · +\(challenge.rewardGold) G")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .opacity(challenge.isCompleted ? 1 : 0.92)
    }
}
