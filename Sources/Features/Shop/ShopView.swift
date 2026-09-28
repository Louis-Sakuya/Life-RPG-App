import SwiftUI

/// 商店。装饰品不改数值；道具页的请假卡 / 保险卡只影响日程与连胜保护。
struct ShopView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette

    /// 嵌在「我的」分页时，背景与标题由父页面接管。
    var embedded: Bool = false

    @State private var kind: ShopItemKind = .consumable
    @State private var errorMessage: String?
    @State private var pickingPauseDate = false
    @State private var pauseDate = Date()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ShopItemKind.allCases, id: \.self) { itemKind in
                        Button {
                            kind = itemKind
                        } label: {
                            Label(itemKind.displayName, systemImage: itemKind.iconName)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(kind == itemKind ? palette.accent.opacity(0.22) : Color.primary.opacity(0.06))
                                )
                                .overlay(
                                    Capsule().strokeBorder(
                                        kind == itemKind ? palette.accent.opacity(0.55) : Color.clear,
                                        lineWidth: 1
                                    )
                                )
                                .foregroundStyle(kind == itemKind ? palette.accent : Color.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }

            List {
                ForEach(store.container.config.shop.items(of: kind)) { item in
                    row(for: item)
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(.secondarySystemGroupedBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(swatch(for: item).opacity(ownedGlow(item)), lineWidth: 1)
                                )
                                .padding(.vertical, 3)
                        )
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            if embedded {
                Color.clear
            } else {
                AtmosphereCanvas()
            }
        }
        .navigationTitle(embedded ? L10n.t("profile.tab.shop") : L10n.t("shop.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                GoldBadge(amount: store.player.gold, infinite: store.isTestShopSandboxEnabled)
            }
        }
        .sheet(isPresented: $pickingPauseDate) {
            NavigationStack {
                Form {
                    DatePicker(
                        L10n.t("shop.pick_pause_day"),
                        selection: $pauseDate,
                        in: store.container.calendar.displayDate(of: store.today)...,
                        displayedComponents: .date
                    )
                }
                .navigationTitle(L10n.t("shop.use_ward"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.t("common.cancel")) { pickingPauseDate = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.t("common.done")) {
                            let day = store.container.calendar.gameDay(fromDisplayDate: pauseDate)
                            if store.useLeaveCard(on: day) {
                                pickingPauseDate = false
                            }
                        }
                        .disabled(store.player.leaveCardCount <= 0)
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .alert(L10n.t("shop.cannot_buy"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(L10n.t("common.ok"), role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func row(for item: ShopItem) -> some View {
        let owned = store.container.shop.isOwned(item)
        let equipped = store.container.shop.isEquipped(item, player: store.player)
        let accent = swatch(for: item)

        return HStack(spacing: 12) {
            preview(for: item, accent: accent)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.localizedName)
                    .font(.body.weight(.medium))
                if !item.localizedDetail.isEmpty {
                    Text(item.localizedDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 6) {
                    if item.requiredLevel > 1 && !store.isTestShopSandboxEnabled {
                        StatPill(icon: "lock.fill", text: "Lv\(item.requiredLevel)", tint: .secondary)
                    }
                    if item.price > 0 {
                        StatPill(icon: "dollarsign.circle.fill", text: "\(item.price)", tint: Color(hex: "#D4A017"))
                    } else {
                        StatPill(icon: "gift.fill", text: L10n.t("common.free"), tint: .green)
                    }
                    if equipped {
                        StatPill(icon: "checkmark.seal.fill", text: L10n.t("common.in_use"), tint: palette.accent)
                    }
                }
            }

            Spacer(minLength: 0)

            if item.kind == .consumable {
                consumableActions(for: item)
            } else if owned {
                Button(equipped
                       ? (store.container.shop.canUnequip(item) ? L10n.t("common.unequip") : L10n.t("common.in_use"))
                       : L10n.t("common.use")
                ) {
                    store.equip(item)
                }
                .buttonStyle(.bordered)
                .disabled(equipped && !store.container.shop.canUnequip(item))
            } else {
                Button(L10n.t("common.buy")) {
                    if let error = store.purchase(item) {
                        errorMessage = error.errorDescription
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func consumableActions(for item: ShopItem) -> some View {
        VStack(alignment: .trailing, spacing: 6) {
            if item.id == ShopItemID.leaveWard, store.player.leaveCardCount > 0 {
                Text(L10n.format("shop.owned_count", store.player.leaveCardCount))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if item.id == ShopItemID.streakShield, store.player.hasStreakShield {
                StatPill(icon: "checkmark.seal.fill", text: L10n.t("shop.shield_ready"), tint: palette.accent)
            }
            HStack(spacing: 8) {
                if item.id == ShopItemID.leaveWard, store.player.leaveCardCount > 0 {
                    Button(L10n.t("shop.use_ward")) {
                        pauseDate = store.container.calendar.displayDate(of: store.today)
                        pickingPauseDate = true
                    }
                    .buttonStyle(.bordered)
                }
                Button(L10n.t("common.buy")) {
                    if let error = store.purchase(item) {
                        errorMessage = error.errorDescription
                    } else if item.id == ShopItemID.leaveWard {
                        pauseDate = store.container.calendar.displayDate(of: store.today)
                        pickingPauseDate = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(item.id == ShopItemID.streakShield && store.player.hasStreakShield && !store.isTestShopSandboxEnabled)
            }
        }
    }

    @ViewBuilder
    private func preview(for item: ShopItem, accent: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(accent.opacity(0.18))
                .frame(width: 46, height: 46)
            switch item.kind {
            case .theme:
                Circle()
                    .fill(LinearGradient(
                        colors: [accent, Color(hex: item.secondaryHex ?? "#8E7CFF")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 26, height: 26)
            case .avatarFrame:
                Circle()
                    .strokeBorder(accent, lineWidth: 3)
                    .frame(width: 26, height: 26)
            default:
                Image(systemName: item.icon)
                    .foregroundStyle(accent)
            }
        }
    }

    private func swatch(for item: ShopItem) -> Color {
        item.accentHex.map { Color(hex: $0) } ?? palette.accent
    }

    private func ownedGlow(_ item: ShopItem) -> Double {
        store.container.shop.isEquipped(item, player: store.player) ? 0.55 : 0.12
    }
}
