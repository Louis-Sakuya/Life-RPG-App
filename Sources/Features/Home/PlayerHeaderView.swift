import SwiftUI

struct PlayerHeaderView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    @State private var isEditingAvatar = false

    var body: some View {
        let progress = store.levelProgress
        let player = store.player

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                avatar

                VStack(alignment: .leading, spacing: 4) {
                    Text(player.nickname)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)

                    if let title = store.currentTitleName {
                        Text(title)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(palette.accent.opacity(0.18)))
                            .foregroundStyle(palette.accent)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 6) {
                    GoldBadge(amount: player.gold, infinite: store.isTestShopSandboxEnabled)
                    StatPill(icon: "flame.fill", text: "\(player.loginStreakCurrent)", tint: .orange)
                }
            }

            HStack(spacing: 10) {
                Text("Lv\(progress.level)")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(palette.accent)
                    .fixedSize()

                VStack(alignment: .leading, spacing: 4) {
                    ProgressBar(value: progress.progress, gradient: palette.gradient)
                    HStack {
                        Text(
                            progress.isMaxLevel
                                ? L10n.t("common.max_level")
                                : L10n.format("exp.progress", progress.currentEXP, progress.requiredEXP)
                        )
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 8)
                        if let tier = store.nextStreakTier {
                            Text(L10n.format(
                                "header.streak_next",
                                tier.days - store.player.loginStreakCurrent,
                                tier.multiplier
                            ))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                        } else if store.streakMultiplier > 1 {
                            Text(L10n.format("header.streak_now", store.streakMultiplier))
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
        .padding(AppMetrics.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppMetrics.cardCornerRadius, style: .continuous)
                .fill(palette.gradient.opacity(palette.plateFillOpacity))
                .shadow(color: palette.accent.opacity(0.16), radius: 12, y: 4)
        )
        .overlay(
            OrnateBorder(
                cornerRadius: AppMetrics.cardCornerRadius,
                colors: palette.ornateColors,
                lineWidth: 1.6
            )
        )
        .sheet(isPresented: $isEditingAvatar) {
            AvatarEditorSheet(player: store.player)
        }
    }

    private var avatar: some View {
        Button {
            isEditingAvatar = true
        } label: {
            AvatarView(
                symbol: store.player.avatarSymbol,
                imageData: store.player.avatarImageData,
                size: 54,
                showsEditBadge: true
            )
            .overlay {
                if let frame = store.equippedFrame {
                    AvatarFrameOverlay(
                        style: frame.styleID,
                        color: Color(hex: frame.accentHex ?? "#B08D57"),
                        size: 54
                    )
                }
            }
            .padding(10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.t("avatar.edit"))
    }
}
