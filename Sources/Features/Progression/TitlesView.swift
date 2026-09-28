import SwiftUI

/// 称号的佩戴。解锁规则与成就完全一致，这里额外提供"选一个戴上"的动作。
struct TitlesView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette

    var body: some View {
        let entries = store.ruleProgress(kind: .title)
        let unlocked = entries.filter(\.isUnlocked)
        let locked = entries.filter { !$0.isUnlocked }.sorted { $0.progress > $1.progress }

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    store.equipTitle(nil)
                } label: {
                    HonorSurface {
                        HStack {
                            Text(L10n.t("title.none"))
                                .foregroundStyle(.primary)
                            Spacer()
                            if store.player.currentTitleID == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(palette.accent)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)

                if unlocked.isEmpty {
                    Text(L10n.t("title.empty"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    honorSectionTitle(L10n.t("unlock.obtained"))
                    ForEach(unlocked, id: \.rule.id) { entry in
                        TitleHonorRow(
                            rule: entry.rule,
                            isEquipped: store.player.currentTitleID == entry.rule.id
                        ) {
                            store.equipTitle(entry.rule.id)
                        }
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
        .navigationTitle(L10n.t("profile.titles"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TitleHonorRow: View {
    @Environment(\.palette) private var palette

    var rule: UnlockRule
    var isEquipped: Bool
    var onEquip: () -> Void

    private var goldTint: Color { Color(hex: "#D4A017") }

    var body: some View {
        HonorSurface {
            HStack(spacing: 12) {
                Image(systemName: isEquipped ? "sparkle" : rule.icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isEquipped ? goldTint : palette.accent)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 3) {
                    Text(rule.localizedName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isEquipped ? goldTint : Color.primary)
                    if !rule.localizedDetail.isEmpty {
                        Text(rule.localizedDetail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 8)

                if isEquipped {
                    Text(L10n.t("title.equipped"))
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .foregroundStyle(goldTint)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(goldTint.opacity(0.85), lineWidth: 1)
                        )
                } else {
                    Button(L10n.t("title.equip"), action: onEquip)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .foregroundStyle(goldTint)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(goldTint.opacity(0.7), lineWidth: 1)
                        )
                }
            }
        }
    }
}
