import SwiftUI

/// 称号的佩戴。解锁规则与成就完全一致，这里额外提供"选一个戴上"的动作。
struct TitlesView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette

    var body: some View {
        List {
            Section {
                Button {
                    store.equipTitle(nil)
                } label: {
                    HStack {
                        Text("不佩戴称号")
                        Spacer()
                        if store.player.currentTitleID == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(palette.accent)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            let entries = store.ruleProgress(kind: .title)
            let unlocked = entries.filter(\.isUnlocked)

            Section("已获得") {
                if unlocked.isEmpty {
                    Text("还没有称号，去完成成就吧")
                        .foregroundStyle(.secondary)
                }
                ForEach(unlocked, id: \.rule.id) { entry in
                    Button {
                        store.equipTitle(entry.rule.id)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: entry.rule.icon)
                                .foregroundStyle(palette.accent)
                                .frame(width: 26)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.rule.name)
                                Text(entry.rule.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if store.player.currentTitleID == entry.rule.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(palette.accent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("未解锁") {
                ForEach(entries.filter { !$0.isUnlocked }, id: \.rule.id) { entry in
                    UnlockRow(rule: entry.rule, progress: entry.progress, text: entry.text, isUnlocked: false)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("称号")
        .navigationBarTitleDisplayMode(.inline)
    }
}
