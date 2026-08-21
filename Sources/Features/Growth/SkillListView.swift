import SwiftUI

struct SkillListView: View {
    @Environment(GameStore.self) private var store
    @Binding var isPresentingEditor: Bool
    @State private var skillToDelete: Skill?

    var body: some View {
        List {
            Section {
                LabeledContent(
                    L10n.t("skill.slots"),
                    value: L10n.format("skill.slots.value", store.learnedSkillCount, store.skillSlotCap)
                )
                Text(store.canLearnSkill
                     ? L10n.t("skill.slots.hint")
                     : L10n.t("skill.slots.full_hint"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if store.skills.isEmpty {
                EmptyStateView(
                    icon: "star.circle",
                    title: L10n.t("skill.empty.title"),
                    message: L10n.t("skill.empty.message"),
                    actionTitle: store.canLearnSkill ? L10n.t("skill.empty.action") : nil,
                    action: store.canLearnSkill ? { isPresentingEditor = true } : nil
                )
                .listRowBackground(Color.clear)
            }

            ForEach(groupedSkills, id: \.stat) { group in
                Section(group.title) {
                    ForEach(group.skills) { skill in
                        NavigationLink {
                            SkillDetailView(skill: skill)
                        } label: {
                            SkillRow(
                                skill: skill,
                                progress: store.skillProgress(skill),
                                questBonus: store.skillQuestBonus(for: skill)
                            )
                        }
                    }
                    .onDelete { offsets in
                        if let index = offsets.first {
                            skillToDelete = group.skills[index]
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .alert(
            L10n.t("skill.delete.title"),
            isPresented: Binding(
                get: { skillToDelete != nil },
                set: { if !$0 { skillToDelete = nil } }
            ),
            presenting: skillToDelete
        ) { skill in
            Button(L10n.t("common.cancel"), role: .cancel) { skillToDelete = nil }
            Button(L10n.t("skill.delete.confirm"), role: .destructive) {
                store.deleteSkill(skill)
                skillToDelete = nil
            }
        } message: { skill in
            Text(L10n.format("skill.delete.message", skill.localizedName, store.skillProgress(skill).level))
        }
    }

    private var groupedSkills: [(stat: String, title: String, skills: [Skill])] {
        var buckets: [CoreStatID: [Skill]] = [:]
        var unassigned: [Skill] = []
        for skill in store.skills {
            if let stat = skill.primaryStat {
                buckets[stat, default: []].append(skill)
            } else {
                unassigned.append(skill)
            }
        }
        var result: [(stat: String, title: String, skills: [Skill])] = []
        for stat in CoreStatID.allCases {
            if let skills = buckets[stat], !skills.isEmpty {
                result.append((stat.rawValue, stat.title, skills))
            }
        }
        if !unassigned.isEmpty {
            result.append(("other", L10n.t("skill.unassigned"), unassigned))
        }
        return result
    }
}

struct SkillRow: View {
    var skill: Skill
    var progress: LevelProgress
    var questBonus: Double = 1

    var body: some View {
        let tint = Color(hex: skill.colorHex)

        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.16))
                    .frame(width: 40, height: 40)
                Image(systemName: skill.iconName)
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(skill.localizedName)
                        .font(.body.weight(.medium))
                    Spacer()
                    Text("Lv\(progress.level)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(tint)
                }
                ProgressBar(
                    value: progress.progress,
                    gradient: LinearGradient(colors: [tint, tint.opacity(0.55)], startPoint: .leading, endPoint: .trailing),
                    height: 6
                )
                HStack {
                    Text(
                        progress.isMaxLevel
                            ? L10n.t("common.max_level")
                            : L10n.format("exp.progress", progress.currentEXP, progress.requiredEXP)
                    )
                    Spacer()
                    if questBonus > 1 {
                        Text(L10n.format("skill.quest_bonus", Int(((questBonus - 1) * 100).rounded())))
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SkillDetailView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var skill: Skill
    @State private var confirmDelete = false

    var body: some View {
        let progress = store.skillProgress(skill)
        let tint = Color(hex: skill.colorHex)

        List {
            Section {
                VStack(spacing: 10) {
                    Image(systemName: skill.iconName)
                        .font(.system(size: 40))
                        .foregroundStyle(tint)
                    Text(skill.localizedName)
                        .font(.title3.weight(.semibold))
                    Text("Lv\(progress.level)")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(tint)
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

            Section(L10n.t("common.data")) {
                LabeledContent(L10n.t("skill.total_exp"), value: "\(skill.totalEXP)")
                LabeledContent(L10n.t("skill.created"), value: skill.createdAt.formatted(date: .abbreviated, time: .omitted))
                LabeledContent(
                    L10n.t("skill.quest_bonus_label"),
                    value: L10n.format("skill.bonus_percent", Int(((store.skillQuestBonus(for: skill) - 1) * 100).rounded()))
                )
                LabeledContent(
                    L10n.t("skill.xp_bonus_label"),
                    value: L10n.format("skill.bonus_percent", Int(((store.skillXPBonus(for: skill) - 1) * 100).rounded()))
                )
            }

            if !skill.affinities.isEmpty {
                Section(L10n.t("skill.affinity")) {
                    ForEach(skill.affinities.sorted { $0.weight > $1.weight }, id: \.stat) { affinity in
                        HStack {
                            Image(systemName: affinity.stat.iconName)
                                .foregroundStyle(Color(hex: affinity.stat.colorHex))
                            Text(affinity.stat.title)
                            Spacer()
                            Text("\(Int((affinity.weight * 100).rounded()))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if !skill.categories.isEmpty {
                Section(L10n.t("common.category")) {
                    let catalog = store.container.config.skillCatalog
                    ForEach(skill.categories, id: \.self) { id in
                        Text(catalog.category(id: id)?.localizedName ?? id)
                    }
                }
            }

            Section {
                Text(L10n.t("skill.footer"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button(L10n.t("skill.delete.action"), role: .destructive) {
                    confirmDelete = true
                }
            }
        }
        .navigationTitle(skill.localizedName)
        .navigationBarTitleDisplayMode(.inline)
        .alert(L10n.t("skill.delete.title"), isPresented: $confirmDelete) {
            Button(L10n.t("common.cancel"), role: .cancel) {}
            Button(L10n.t("skill.delete.confirm"), role: .destructive) {
                store.deleteSkill(skill)
                dismiss()
            }
        } message: {
            Text(L10n.format("skill.delete.message", skill.localizedName, store.skillProgress(skill).level))
        }
    }
}
