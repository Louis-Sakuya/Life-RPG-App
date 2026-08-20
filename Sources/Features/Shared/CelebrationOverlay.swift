import SwiftUI

/// 升级与解锁的庆祝弹层。
///
/// 反馈是 RPG 化最关键的一环：如果完成任务只是让一个数字悄悄变大，
/// 玩家感受不到"角色在成长"。事件由 `GameStore` 排队，这里逐个消费。
struct CelebrationOverlay: ViewModifier {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let event = store.pendingLevelUps.first {
                    banner(
                        icon: event.skillName == nil ? "sparkles" : "star.circle.fill",
                        title: event.skillName == nil ? "升级！Lv\(event.level)" : "\(event.skillName!) 升到 Lv\(event.level)",
                        subtitle: event.goldReward > 0 ? "获得 \(event.goldReward) 金币" : nil
                    )
                    .id(event.id)
                    .task(id: event.id) {
                        try? await Task.sleep(for: .seconds(2.2))
                        if !store.pendingLevelUps.isEmpty {
                            store.pendingLevelUps.removeFirst()
                        }
                    }
                } else if let unlock = store.pendingUnlocks.first {
                    banner(
                        icon: unlock.icon,
                        title: "\(unlock.kind.displayName)解锁：\(unlock.name)",
                        subtitle: unlock.detail.isEmpty ? nil : unlock.detail
                    )
                    .id(unlock.id)
                    .task(id: unlock.id) {
                        try? await Task.sleep(for: .seconds(2.2))
                        if !store.pendingUnlocks.isEmpty {
                            store.pendingUnlocks.removeFirst()
                        }
                    }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: store.pendingLevelUps.count)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: store.pendingUnlocks.count)
    }

    private func banner(icon: String, title: String, subtitle: String?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Circle().fill(palette.gradient))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        )
        .padding(.horizontal, 16)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

extension View {
    func celebrationOverlay() -> some View {
        modifier(CelebrationOverlay())
    }
}
