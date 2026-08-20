import SwiftUI

/// 挑战列表。进度不存库，而是每次由 `UnlockEngine` 用当前统计量算出来，
/// 因此永远不会出现"进度条和真实数据对不上"的情况。
struct ChallengeListView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette

    @State private var isPresentingEditor = false

    var body: some View {
        List {
            let entries = store.challengeProgress()
            let ongoing = entries.filter { !$0.challenge.isCompleted }
            let finished = entries.filter { $0.challenge.isCompleted }

            Section {
                if ongoing.isEmpty {
                    Text("没有进行中的挑战")
                        .foregroundStyle(.secondary)
                }
                ForEach(ongoing, id: \.challenge.id) { entry in
                    ChallengeRow(challenge: entry.challenge, progress: entry.progress, text: entry.text)
                }
            } header: {
                Text("进行中")
            } footer: {
                Text("挑战是长期目标，进度由你的实际数据自动推导，不需要手动打勾。")
            }

            if !finished.isEmpty {
                Section("已完成") {
                    ForEach(finished, id: \.challenge.id) { entry in
                        ChallengeRow(challenge: entry.challenge, progress: 1, text: entry.text)
                    }
                }
            }

            Section {
                Button {
                    isPresentingEditor = true
                } label: {
                    Label("自定义挑战", systemImage: "plus.circle")
                }
            }
        }
        .listStyle(.insetGrouped)
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

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(palette.accent.opacity(challenge.isCompleted ? 0.9 : 0.14))
                    .frame(width: 40, height: 40)
                Image(systemName: challenge.isCompleted ? "checkmark" : challenge.iconName)
                    .foregroundStyle(challenge.isCompleted ? .white : palette.accent)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(challenge.title)
                    .font(.body.weight(.medium))
                if !challenge.detail.isEmpty {
                    Text(challenge.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ProgressBar(value: progress, gradient: palette.gradient, height: 6)
                HStack {
                    if let text {
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
        .padding(.vertical, 4)
    }
}
