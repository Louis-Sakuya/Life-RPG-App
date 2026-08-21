import SwiftUI

struct SkillEditorView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .catalog
    @State private var name = ""
    @State private var iconName = "star.fill"
    @State private var colorHex = "#5B8DEF"
    @State private var selectedCategories: Set<String> = []
    @State private var affinities: [CoreStatID: Double] = Dictionary(
        uniqueKeysWithValues: CoreStatID.allCases.map { ($0, 0.2) }
    )

    private enum Mode: String, CaseIterable, Identifiable {
        case catalog, custom
        var id: String { rawValue }
        var title: String { self == .catalog ? L10n.t("skill.catalog") : L10n.t("skill.custom") }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker(L10n.t("skill.method"), selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                if mode == .catalog {
                    catalogList
                } else {
                    customForm
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(L10n.t("skill.add"))
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top) {
                if !store.canLearnSkill {
                    Text(L10n.format("skill.slots.full", store.learnedSkillCount, store.skillSlotCap))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("common.cancel")) { dismiss() }
                }
                if mode == .custom {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.t("common.save"), action: saveCustom)
                            .disabled(!canSaveCustom || !store.canLearnSkill)
                    }
                }
            }
        }
    }

    private var catalogList: some View {
        List {
            ForEach(CoreStatID.allCases) { stat in
                let presets = store.container.config.skillCatalog.presets(for: stat)
                if !presets.isEmpty {
                    Section(stat.title) {
                        ForEach(presets) { preset in
                            Button {
                                if store.createSkill(from: preset) {
                                    dismiss()
                                }
                            } label: {
                                SkillPresetRow(preset: preset, catalog: store.container.config.skillCatalog)
                            }
                            .disabled(!store.canLearnSkill)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var customForm: some View {
        Form {
            Section(L10n.t("common.name")) {
                TextField(L10n.t("skill.name_placeholder"), text: $name)
            }
            Section(L10n.t("common.icon")) {
                IconPicker(selection: $iconName, tint: Color(hex: colorHex))
            }
            Section(L10n.t("common.color")) {
                ColorPickerRow(selection: $colorHex)
            }
            Section(L10n.t("common.category")) {
                let categories = store.container.config.skillCatalog.categories
                if categories.isEmpty {
                    Text(L10n.t("skill.no_categories"))
                        .foregroundStyle(.secondary)
                } else {
                    FlexibleCategoryPicker(categories: categories, selection: $selectedCategories)
                }
            }
            Section {
                StatAffinityEditor(shares: $affinities)
            } header: {
                Text(L10n.t("skill.affinity"))
            } footer: {
                Text(L10n.t("skill.affinity_footer"))
            }
        }
    }

    private var canSaveCustom: Bool {
        let hasName = !name.trimmingCharacters(in: .whitespaces).isEmpty
        let total = affinities.values.reduce(0, +)
        return hasName && abs(total - 1) <= 0.02
    }

    private func saveCustom() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsed = affinities.compactMap { key, value -> StatAffinity? in
            value > 0 ? StatAffinity(stat: key, weight: value) : nil
        }
        if store.createSkill(
            name: trimmed,
            iconName: iconName,
            colorHex: colorHex,
            categories: Array(selectedCategories),
            affinities: parsed
        ) {
            dismiss()
        }
    }
}

struct SkillPresetRow: View {
    var preset: SkillPreset
    var catalog: SkillCatalog

    var body: some View {
        let tint = Color(hex: preset.color)
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(tint.opacity(0.16)).frame(width: 40, height: 40)
                Image(systemName: preset.icon).foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(preset.localizedName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text(affinityText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(tint)
        }
        .padding(.vertical, 4)
    }

    private var affinityText: String {
        preset.parsedAffinities
            .sorted { $0.weight > $1.weight }
            .map { "\($0.stat.title) \(Int(($0.weight * 100).rounded()))%" }
            .joined(separator: " · ")
    }
}

struct StatAffinityEditor: View {
    @Binding var shares: [CoreStatID: Double]

    var body: some View {
        let total = shares.values.reduce(0, +)
        HStack {
            Text(L10n.t("skill.share_header"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(L10n.format("skill.allocated", Int((total * 100).rounded())))
                .font(.caption.weight(.semibold))
                .foregroundStyle(abs(total - 1) <= 0.02 ? Color.green : Color.orange)
        }

        ForEach(CoreStatID.allCases) { stat in
            let share = shares[stat] ?? 0
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: stat.iconName)
                        .foregroundStyle(Color(hex: stat.colorHex))
                    Text(stat.title)
                    Spacer()
                    Text("\(Int((share * 100).rounded()))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { shares[stat] ?? 0 },
                        set: { newValue in
                            shares = redistributed(setting: stat, to: newValue)
                        }
                    ),
                    in: 0...1
                )
                .tint(Color(hex: stat.colorHex))
            }
        }
    }

    private func redistributed(setting stat: CoreStatID, to raw: Double) -> [CoreStatID: Double] {
        let uuidMap = Dictionary(uniqueKeysWithValues: CoreStatID.allCases.map { ($0, uuid($0)) })
        var asUUID: [UUID: Double] = [:]
        for item in CoreStatID.allCases {
            asUUID[uuidMap[item]!] = shares[item] ?? 0
        }
        let next = SkillShareMath.setShare(
            raw,
            for: uuidMap[stat]!,
            in: asUUID,
            ids: CoreStatID.allCases.map { uuidMap[$0]! },
            keepFullAllocation: true
        )
        var result: [CoreStatID: Double] = [:]
        for item in CoreStatID.allCases {
            result[item] = next[uuidMap[item]!] ?? 0
        }
        return result
    }

    private func uuid(_ stat: CoreStatID) -> UUID {
        switch stat {
        case .body: return UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        case .mind: return UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        case .life: return UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        case .social: return UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
        case .creation: return UUID(uuidString: "00000000-0000-0000-0000-000000000005")!
        }
    }
}

struct FlexibleCategoryPicker: View {
    var categories: [SkillCategory]
    @Binding var selection: Set<String>

    var body: some View {
        ForEach(categories) { category in
            Button {
                if selection.contains(category.id) {
                    selection.remove(category.id)
                } else {
                    selection.insert(category.id)
                }
            } label: {
                HStack {
                    Image(systemName: category.icon)
                    Text(category.localizedName)
                    Spacer()
                    if selection.contains(category.id) {
                        Image(systemName: "checkmark")
                    }
                }
            }
            .foregroundStyle(.primary)
        }
    }
}
