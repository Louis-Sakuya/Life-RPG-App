import SwiftUI

// MARK: - 卡片容器

struct Card<Content: View>: View {
    @Environment(\.palette) private var palette
    var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(AppMetrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppMetrics.cardCornerRadius, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: palette.accent.opacity(0.12), radius: 10, y: 4)
            )
            .overlay(
                OrnateBorder(
                    cornerRadius: AppMetrics.cardCornerRadius,
                    colors: palette.ornateColors
                )
            )
    }
}

struct SectionHeader: View {
    var title: String
    var subtitle: String?
    var actionTitle: String?
    var action: (() -> Void)?

    init(_ title: String, subtitle: String? = nil, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline)
            }
        }
    }
}

// MARK: - 工会选择卡片

struct GuildChoiceCard: View {
    var icon: String
    var title: String
    var subtitle: String
    var detail: String
    var tint: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(tint)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(tint.opacity(0.16))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(tint)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 14)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(tint.opacity(0.28), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 进度条

struct ProgressBar: View {
    var value: Double
    var gradient: LinearGradient
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.1))
                Capsule()
                    .fill(gradient)
                    .frame(width: max(0, min(1, value)) * geometry.size.width)
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(Color.white.opacity(0.28))
                            .frame(height: max(2, height * 0.35))
                            .padding(.horizontal, 4)
                            .padding(.top, 1)
                    }
                    .clipShape(Capsule())
            }
        }
        .frame(height: height)
        .animation(.easeOut(duration: 0.35), value: value)
    }
}

// MARK: - 小标签

struct StatPill: View {
    var icon: String
    var text: String
    var tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(tint.opacity(0.15)))
        .foregroundStyle(tint)
    }
}

/// 金币余额。不用美元符号，避免被挤成只剩图标、数字消失。
struct GoldBadge: View {
    var amount: Int
    var showsPrefix: Bool = false
    var infinite: Bool = false

    private var goldTint: Color { Color(hex: "#D4A017") }

    var body: some View {
        HStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(goldTint)
                    .frame(width: 16, height: 16)
                Text("G")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
            Text(label)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(goldTint)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Capsule().fill(goldTint.opacity(0.16)))
        .fixedSize()
        .accessibilityLabel(
            infinite ? L10n.t("gold.accessibility.infinite") : L10n.format("gold.accessibility", amount)
        )
    }

    private var label: String {
        if infinite { return L10n.t("gold.infinite") }
        if showsPrefix && amount > 0 { return "+\(amount)" }
        return "\(amount)"
    }
}

struct TagChip: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.primary.opacity(0.08)))
            .foregroundStyle(.secondary)
    }
}

/// 荣誉页与成就/称号详情共用的卡片底。
struct HonorSurface<Content: View>: View {
    var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                    )
            )
    }
}

struct DifficultyStars: View {
    var value: Int
    var tint: Color

    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= value ? "star.fill" : "star")
                    .font(.system(size: 8))
            }
        }
        .foregroundStyle(tint)
    }
}

// MARK: - 空状态

struct EmptyStateView: View {
    var icon: String
    var title: String
    var message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 34))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

// MARK: - 图标选择

struct IconPicker: View {
    @Binding var selection: String
    var tint: Color

    static let options = [
        "star.fill", "book.fill", "figure.run", "drop.fill", "leaf.fill",
        "flame.fill", "moon.stars.fill", "sun.max.fill", "heart.fill", "brain.head.profile",
        "chevron.left.forwardslash.chevron.right", "gamecontroller.fill", "paintpalette.fill",
        "music.note", "dollarsign.circle.fill", "fork.knife", "bed.double.fill",
        "figure.strengthtraining.traditional", "pencil.and.outline", "character.book.closed.fill"
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Self.options, id: \.self) { name in
                    Button {
                        selection = name
                    } label: {
                        Image(systemName: name)
                            .font(.system(size: 18))
                            .frame(width: 42, height: 42)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(selection == name ? tint.opacity(0.22) : Color.primary.opacity(0.06))
                            )
                            .foregroundStyle(selection == name ? tint : Color.primary.opacity(0.65))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

struct ColorPickerRow: View {
    @Binding var selection: String

    static let options = [
        "#5B8DEF", "#8E7CFF", "#2FA36B", "#C9A227", "#E2603B",
        "#E86A92", "#3EC1B3", "#9A6BFF", "#D4A017", "#6B7280"
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Self.options, id: \.self) { hex in
                    Button {
                        selection = hex
                    } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 30, height: 30)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.primary.opacity(selection == hex ? 0.65 : 0), lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

// MARK: - 技能经验分配

struct SkillShareEditor: View {
    var skills: [Skill]
    @Binding var shares: [UUID: Double]
    /// 为 true 时所有技能共用 100%，拖动一个会按比例改写其余技能
    var requiresFullAllocation: Bool = false

    private var total: Double { SkillShareMath.total(shares) }

    var body: some View {
        if skills.isEmpty {
            Text(L10n.t("skill.no_share"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            HStack {
                Text(requiresFullAllocation ? L10n.t("skill.share_all") : L10n.t("skill.share_partial"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(L10n.format("skill.allocated", Int((total * 100).rounded())))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SkillShareMath.isFullAllocation(shares) ? Color.green : Color.orange)
            }

            ForEach(skills) { skill in
                let share = shares[skill.id] ?? 0
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: skill.iconName)
                            .foregroundStyle(Color(hex: skill.colorHex))
                        Text(skill.localizedName)
                        Spacer()
                        Text(share > 0 ? "\(Int((share * 100).rounded()))%" : L10n.t("common.close"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: Binding(
                            get: { shares[skill.id] ?? 0 },
                            set: { newValue in
                                shares = SkillShareMath.setShare(
                                    newValue,
                                    for: skill.id,
                                    in: shares,
                                    ids: skills.map(\.id),
                                    keepFullAllocation: requiresFullAllocation
                                )
                            }
                        ),
                        in: 0...1
                    )
                    .tint(Color(hex: skill.colorHex))
                }
            }
        }
    }
}

extension Dictionary where Key == UUID, Value == Double {
    var asSkillShares: [SkillShare] {
        compactMap { key, value in
            value > 0 ? SkillShare(skillID: key, expShare: value) : nil
        }
    }
}

/// 发布任务时可点多项技能，完成后经验平均分给所选技能。
struct SkillPickList: View {
    var skills: [Skill]
    @Binding var selectedIDs: Set<UUID>

    var body: some View {
        if skills.isEmpty {
            Text(L10n.t("skill.no_share"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            VStack(spacing: 8) {
                ForEach(skills) { skill in
                    let selected = selectedIDs.contains(skill.id)
                    let tint = Color(hex: skill.colorHex)
                    Button {
                        if selected {
                            selectedIDs.remove(skill.id)
                        } else {
                            selectedIDs.insert(skill.id)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: skill.iconName)
                                .foregroundStyle(selected ? Color.white : tint)
                                .frame(width: 22)
                            Text(skill.localizedName)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(selected ? Color.white : Color.primary)
                            Spacer()
                            if selected {
                                Image(systemName: "checkmark")
                                    .font(.footnote.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(selected ? tint : tint.opacity(0.12))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// 主线任务：时长决定难度，优先级由玩家自己选。
struct QuestChallengeFields: View {
    @Binding var estimatedMinutes: Int
    @Binding var priority: QuestPriority

    var autoDifficulty: QuestDifficulty {
        .fromEstimatedMinutes(estimatedMinutes)
    }

    var body: some View {
        Stepper(
            L10n.format("quest.estimated_stepper", estimatedMinutes),
            value: $estimatedMinutes,
            in: 5...600,
            step: 5
        )
        LabeledContent(L10n.t("quest.difficulty"), value: autoDifficulty.title)
        Picker(L10n.t("quest.priority"), selection: $priority) {
            ForEach(QuestPriority.allCases) { Text($0.title).tag($0) }
        }
    }
}

extension View {
    /// 结束远行前弹出旅途天数与归途奖励，避免误触。
    func recurringFinishConfirmation(template: Binding<QuestTemplate?>) -> some View {
        modifier(RecurringFinishConfirmationModifier(template: template))
    }
}

private struct RecurringFinishConfirmationModifier: ViewModifier {
    @Environment(GameStore.self) private var store
    @Binding var template: QuestTemplate?

    func body(content: Content) -> some View {
        content.alert(
            L10n.t("quest.finish.title"),
            isPresented: Binding(
                get: { template != nil },
                set: { if !$0 { template = nil } }
            )
        ) {
            Button(L10n.t("quest.finish.action")) {
                if let template {
                    store.finishTemplate(template)
                }
            }
            Button(L10n.t("common.cancel"), role: .cancel) {}
        } message: {
            if let template {
                let reward = store.previewFinishTemplate(template)
                Text(
                    L10n.format(
                        "quest.finish.message",
                        reward.tier.title,
                        reward.durationDays,
                        reward.completions,
                        reward.exp,
                        reward.gold
                    )
                )
            }
        }
    }
}
