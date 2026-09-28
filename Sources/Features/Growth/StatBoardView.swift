import SwiftUI

struct StatBoardView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(L10n.t("stat.philosophy"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(CoreStatID.allCases) { stat in
                    NavigationLink {
                        StatDetailView(stat: stat)
                    } label: {
                        StatCard(stat: stat, progress: store.statProgress(stat))
                    }
                    .buttonStyle(.plain)
                }

                LuckyCard(progress: store.luckyProgress(), fortune: store.todayFortune)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(.clear)
    }
}

struct StatCard: View {
    @Environment(GameStore.self) private var store
    var stat: CoreStatID
    var progress: LevelProgress

    var body: some View {
        let tint = Color(hex: stat.colorHex)
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.16))
                    .frame(width: 48, height: 48)
                Image(systemName: stat.iconName)
                    .font(.title3)
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(stat.title)
                        .font(.headline)
                    if !L10n.isEnglish {
                        Text(stat.englishTitle)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(tint)
                    }
                    Spacer()
                    Text("Lv\(store.effectiveStatLevel(stat))")
                        .font(.headline)
                        .foregroundStyle(tint)
                }
                if store.allocatedPoints(for: stat) > 0 {
                    Text(L10n.format("stat.allocated", store.allocatedPoints(for: stat)))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(tint)
                }
                Text(stat.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                ProgressBar(
                    value: progress.progress,
                    gradient: LinearGradient(colors: [tint, tint.opacity(0.55)], startPoint: .leading, endPoint: .trailing),
                    height: 7
                )
                Text(
                    progress.isMaxLevel
                        ? L10n.t("common.max_level")
                        : L10n.format("exp.progress", progress.currentEXP, progress.requiredEXP)
                )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

struct LuckyCard: View {
    var progress: LevelProgress
    var fortune: FortuneTier?

    var body: some View {
        let tint = Color(hex: HiddenStatID.lucky.colorHex)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint.opacity(0.16))
                        .frame(width: 48, height: 48)
                    Image(systemName: HiddenStatID.lucky.iconName)
                        .font(.title3)
                        .foregroundStyle(tint)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(HiddenStatID.lucky.title)
                            .font(.headline)
                        Text(L10n.t("common.hidden"))
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(tint.opacity(0.18)))
                            .foregroundStyle(tint)
                        Spacer()
                        Text("Lv\(progress.level)")
                            .font(.headline)
                            .foregroundStyle(tint)
                    }
                    Text(HiddenStatID.lucky.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ProgressBar(
                value: progress.progress,
                gradient: LinearGradient(colors: [tint, Color(hex: "#E8D48B")], startPoint: .leading, endPoint: .trailing),
                height: 7
            )

            Text(HiddenStatID.lucky.definition)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let fortune {
                Text(L10n.format("lucky.today", fortune.localizedName, fortune.bonusPercentText))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(tint.opacity(0.35), lineWidth: 1)
                )
        )
    }
}

struct StatDetailView: View {
    @Environment(GameStore.self) private var store
    var stat: CoreStatID

    var body: some View {
        let progress = store.statProgress(stat)
        let tint = Color(hex: stat.colorHex)
        let feeding = store.skills(feeding: stat)

        List {
            Section {
                VStack(spacing: 10) {
                    Image(systemName: stat.iconName)
                        .font(.system(size: 36))
                        .foregroundStyle(tint)
                    Text(stat.title)
                        .font(.title3.weight(.semibold))
                    if !L10n.isEnglish {
                        Text(stat.englishTitle)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(tint)
                    }
                    Text("Lv\(store.effectiveStatLevel(stat))")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(tint)
                    if store.allocatedPoints(for: stat) > 0 {
                        Text(L10n.format("stat.allocated_detail", store.allocatedPoints(for: stat), progress.level))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ProgressBar(
                        value: progress.progress,
                        gradient: LinearGradient(colors: [tint, tint.opacity(0.55)], startPoint: .leading, endPoint: .trailing)
                    )
                    Text(
                        progress.isMaxLevel
                            ? L10n.t("common.max_level")
                            : L10n.format("exp.to_next", progress.remainingEXP)
                    )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section(L10n.t("common.definition")) {
                Text(stat.definition)
            }

            Section(L10n.t("common.domains")) {
                FlexibleChipWrap(items: stat.domains)
            }

            Section(L10n.t("stat.effect")) {
                let bonus = ProgressionEngine.bonus(
                    level: store.effectiveStatLevel(stat),
                    perLevel: store.container.config.balance.statSkillXPBonusPerLevel,
                    cap: store.container.config.balance.statSkillXPBonusMax
                )
                Text(L10n.format("stat.effect.detail", Int(((bonus - 1) * 100).rounded())))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(L10n.t("stat.feeding")) {
                if feeding.isEmpty {
                    Text(L10n.t("stat.feeding.empty"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(feeding) { skill in
                        let share = skill.affinities.first { $0.stat == stat }?.weight ?? 0
                        HStack {
                            Image(systemName: skill.iconName)
                                .foregroundStyle(Color(hex: skill.colorHex))
                            Text(skill.localizedName)
                            Spacer()
                            Text("\(Int((share * 100).rounded()))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(stat.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct FlexibleChipWrap: View {
    var items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                TagChip(text: item)
            }
        }
    }
}
