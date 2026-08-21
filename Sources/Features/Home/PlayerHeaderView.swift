import SwiftUI

struct PlayerHeaderView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette

    var body: some View {
        let progress = store.levelProgress
        let player = store.player

        VStack(spacing: 12) {
            HStack(spacing: 14) {
                avatar

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(player.nickname)
                            .font(.title3.weight(.semibold))
                        if let title = store.currentTitleName {
                            Text(title)
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(palette.accent.opacity(0.18)))
                                .foregroundStyle(palette.accent)
                        }
                    }

                    HStack(spacing: 8) {
                        Text("Lv\(progress.level)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(palette.accent)
                            .fixedSize()
                        Text(dateText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Text(L10n.format("header.day_n", max(1, player.totalDaysPlayed)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 6) {
                    GoldBadge(amount: player.gold, infinite: store.isTestShopSandboxEnabled)
                    StatPill(icon: "flame.fill", text: "\(player.loginStreakCurrent)", tint: .orange)
                }
            }

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
                    Spacer()
                    if let tier = store.nextStreakTier {
                        Text(L10n.format(
                            "header.streak_next",
                            tier.days - store.player.loginStreakCurrent,
                            tier.multiplier
                        ))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else if store.streakMultiplier > 1 {
                        Text(L10n.format("header.streak_now", store.streakMultiplier))
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(AppMetrics.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppMetrics.cardCornerRadius, style: .continuous)
                .fill(palette.gradient.opacity(0.14))
        )
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(palette.gradient)
                .frame(width: 54, height: 54)
            if let data = store.player.avatarImageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
            } else {
                Image(systemName: store.player.avatarSymbol)
                    .font(.system(size: 26))
                    .foregroundStyle(.white)
            }
        }
        .overlay(
            Circle()
                .strokeBorder(frameColor, lineWidth: store.player.currentFrameID == nil ? 0 : 3)
                .frame(width: 60, height: 60)
        )
    }

    private var frameColor: Color {
        guard let id = store.player.currentFrameID,
              let item = store.container.config.shop.item(id: id),
              let hex = item.accentHex else { return .clear }
        return Color(hex: hex)
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = L10n.locale
        formatter.setLocalizedDateFormatFromTemplate("MMMd EEE")
        return formatter.string(from: store.container.calendar.displayDate(of: store.today))
    }
}
