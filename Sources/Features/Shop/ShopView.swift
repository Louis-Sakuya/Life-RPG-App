import SwiftUI

/// 商店。全部商品都是纯装饰，不影响任何数值。
/// 这条约束保证金币可以放心地作为长期激励发放，而不会破坏任务奖励的平衡。
struct ShopView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette

    @State private var kind: ShopItemKind = .theme
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            Picker(L10n.t("shop.kind"), selection: $kind) {
                ForEach(ShopItemKind.allCases, id: \.self) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            List {
                ForEach(store.container.config.shop.items(of: kind)) { item in
                    row(for: item)
                }
            }
            .listStyle(.insetGrouped)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(L10n.t("shop.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                GoldBadge(amount: store.player.gold, infinite: store.isTestShopSandboxEnabled)
            }
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
        let accent = item.accentHex.map { Color(hex: $0) } ?? palette.accent

        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(accent.opacity(0.18))
                    .frame(width: 42, height: 42)
                Image(systemName: item.icon)
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.localizedName)
                    .font(.body.weight(.medium))
                if !item.localizedDetail.isEmpty {
                    Text(item.localizedDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                }
            }

            Spacer(minLength: 0)

            if owned {
                Button(equipped ? L10n.t("common.in_use") : L10n.t("common.use")) {
                    store.equip(item)
                }
                .buttonStyle(.bordered)
                .disabled(equipped || !isEquippable(item))
            } else {
                Button(L10n.t("common.buy")) {
                    if let error = store.purchase(item) {
                        errorMessage = error.errorDescription
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 4)
    }

    private func isEquippable(_ item: ShopItem) -> Bool {
        switch item.kind {
        case .theme, .background, .avatarFrame: return true
        case .effect, .sound, .pet: return false
        }
    }
}
