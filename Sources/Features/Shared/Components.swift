import SwiftUI

// MARK: - 卡片容器

struct Card<Content: View>: View {
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
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(tint.opacity(0.15)))
        .foregroundStyle(tint)
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

    var body: some View {
        if skills.isEmpty {
            Text("还没有技能，先去成长页创建一个")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            ForEach(skills) { skill in
                let share = shares[skill.id] ?? 0
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: skill.iconName)
                            .foregroundStyle(Color(hex: skill.colorHex))
                        Text(skill.name)
                        Spacer()
                        Text(share > 0 ? "\(Int(share * 100))%" : "关闭")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: Binding(
                            get: { shares[skill.id] ?? 0 },
                            set: { shares[skill.id] = ($0 * 20).rounded() / 20 }
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
