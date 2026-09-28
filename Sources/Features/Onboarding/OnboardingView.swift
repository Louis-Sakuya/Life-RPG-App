import SwiftUI

struct OnboardingView: View {
    private enum Step: Int {
        case title
        case skills
    }

    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette
    @FocusState private var isTitleFocused: Bool

    @State private var step: Step = .title
    @State private var nickname = ""
    @State private var avatarSymbol = Player.defaultAvatarSymbol
    @State private var avatarImageData: Data?
    @State private var drafts: [OnboardingSkillDraft] = []
    @State private var isPresentingCustom = false

    private var trimmedNickname: String {
        nickname.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canContinueTitle: Bool {
        !trimmedNickname.isEmpty
    }

    private var maxInitialSkills: Int {
        max(1, store.container.config.balance.initialSkillSlots)
    }

    private var remainingSlots: Int {
        max(0, maxInitialSkills - drafts.count)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                stepHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                Group {
                    switch step {
                    case .title: titleStep
                    case .skills: skillsStep
                    }
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(L10n.t("onboarding.nav"))
                        .font(.headline)
                }
                if step == .skills {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(L10n.t("common.back")) {
                            withAnimation(.easeInOut(duration: 0.25)) { step = .title }
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                footer
            }
            .sheet(isPresented: $isPresentingCustom) {
                OnboardingCustomSkillView { draft in
                    guard remainingSlots > 0 else { return }
                    drafts.append(draft)
                }
            }
        }
    }

    // MARK: - 步骤指示

    private var stepHeader: some View {
        HStack(spacing: 10) {
            stepDot(index: 0, title: L10n.t("onboarding.step.title"))
            Capsule()
                .fill(step == .skills ? palette.accent.opacity(0.55) : Color.primary.opacity(0.12))
                .frame(height: 3)
            stepDot(index: 1, title: L10n.t("onboarding.step.skills"))
        }
    }

    private func stepDot(index: Int, title: String) -> some View {
        let isActive = step.rawValue >= index
        return VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isActive ? palette.accent : Color.primary.opacity(0.12))
                    .frame(width: 28, height: 28)
                Text("\(index + 1)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isActive ? Color.white : Color.secondary)
            }
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(isActive ? Color.primary : Color.secondary)
        }
    }

    // MARK: - 称号

    private var titleStep: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 8) {
                    Text(L10n.t("onboarding.welcome"))
                        .font(.largeTitle.weight(.bold))
                        .multilineTextAlignment(.center)
                    Text(L10n.t("onboarding.title.subtitle"))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.t("onboarding.avatar.label"))
                        .font(.subheadline.weight(.semibold))
                    Text(L10n.t("onboarding.avatar.subtitle"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    AvatarPicker(symbol: $avatarSymbol, imageData: $avatarImageData, previewSize: 96)
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.t("onboarding.title.label"))
                        .font(.subheadline.weight(.semibold))
                    TextField(L10n.t("onboarding.title.placeholder"), text: $nickname)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused($isTitleFocused)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                        .onChange(of: nickname) { _, newValue in
                            if newValue.count > 16 {
                                nickname = String(newValue.prefix(16))
                            }
                        }
                    Text(L10n.t("onboarding.title.footer"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 16)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - 技能

    private var skillsStep: some View {
        List {
            Section {
                Text(L10n.format("onboarding.skills.hello", trimmedNickname))
                    .font(.title3.weight(.semibold))
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 0, trailing: 4))
                    Text(L10n.format("onboarding.skills.subtitle", maxInitialSkills))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 8, trailing: 4))
            }

            if !drafts.isEmpty {
                Section(L10n.format("onboarding.skills.selected", drafts.count, maxInitialSkills)) {
                    selectedChips
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                }
            } else {
                Section {
                    Text(L10n.format("onboarding.skills.count", drafts.count, maxInitialSkills))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    isPresentingCustom = true
                } label: {
                    Label(L10n.t("onboarding.skills.custom"), systemImage: "plus.square.dashed")
                }
                .disabled(remainingSlots == 0)
            } footer: {
                Text(remainingSlots == 0
                     ? L10n.t("onboarding.skills.full")
                     : L10n.t("onboarding.skills.custom_footer"))
            }

            ForEach(CoreStatID.allCases) { stat in
                let presets = store.container.config.skillCatalog.presets(for: stat)
                if !presets.isEmpty {
                    Section(stat.title) {
                        ForEach(presets) { preset in
                            let selected = isSelected(preset)
                            Button {
                                toggle(preset)
                            } label: {
                                OnboardingPresetRow(
                                    preset: preset,
                                    isSelected: selected,
                                    isDisabled: !selected && remainingSlots == 0
                                )
                            }
                            .disabled(!selected && remainingSlots == 0)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var selectedChips: some View {
        FlexibleSkillChips(drafts: drafts) { draft in
            drafts.removeAll { $0.id == draft.id }
        }
    }

    // MARK: - 底部按钮

    private var footer: some View {
        VStack(spacing: 10) {
            Button(action: primaryAction) {
                Text(primaryTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(palette.accent)
            .disabled(step == .title && !canContinueTitle)

            if step == .skills {
                Text(L10n.t("onboarding.skills.skip_hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.bar)
    }

    private var primaryTitle: String {
        switch step {
        case .title: return L10n.t("onboarding.next")
        case .skills: return L10n.t("onboarding.start")
        }
    }

    private func primaryAction() {
        switch step {
        case .title:
            guard canContinueTitle else { return }
            isTitleFocused = false
            withAnimation(.easeInOut(duration: 0.25)) { step = .skills }
        case .skills:
            store.completeOnboarding(
                nickname: trimmedNickname,
                avatarSymbol: avatarSymbol,
                avatarImageData: avatarImageData,
                skills: drafts
            )
        }
    }

    // MARK: - 选择

    private func isSelected(_ preset: SkillPreset) -> Bool {
        drafts.contains { $0.catalogID == preset.id }
    }

    private func toggle(_ preset: SkillPreset) {
        if let index = drafts.firstIndex(where: { $0.catalogID == preset.id }) {
            drafts.remove(at: index)
        } else if remainingSlots > 0 {
            drafts.append(.fromPreset(preset))
        }
    }

}

private struct OnboardingPresetRow: View {
    var preset: SkillPreset
    var isSelected: Bool
    var isDisabled: Bool

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
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? tint : Color.secondary.opacity(0.45))
        }
        .padding(.vertical, 4)
        .opacity(isDisabled ? 0.45 : 1)
    }

    private var affinityText: String {
        preset.parsedAffinities
            .sorted { $0.weight > $1.weight }
            .map { "\($0.stat.title) \(Int(($0.weight * 100).rounded()))%" }
            .joined(separator: " · ")
    }
}

private struct FlexibleSkillChips: View {
    var drafts: [OnboardingSkillDraft]
    var onRemove: (OnboardingSkillDraft) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(drafts) { draft in
                    let tint = Color(hex: draft.colorHex)
                    HStack(spacing: 6) {
                        Image(systemName: draft.iconName)
                        Text(draft.localizedName)
                            .font(.caption.weight(.semibold))
                        Button {
                            onRemove(draft)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(tint.opacity(0.16)))
                    .foregroundStyle(tint)
                }
            }
        }
    }
}

private struct OnboardingCustomSkillView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var onSave: (OnboardingSkillDraft) -> Void

    @State private var name = ""
    @State private var iconName = "star.fill"
    @State private var colorHex = "#5B8DEF"
    @State private var selectedCategories: Set<String> = []
    @State private var affinities: [CoreStatID: Double] = Dictionary(
        uniqueKeysWithValues: CoreStatID.allCases.map { ($0, 0.2) }
    )

    var body: some View {
        NavigationStack {
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
            .navigationTitle(L10n.t("skill.custom"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("common.save"), action: save)
                        .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        let hasName = !name.trimmingCharacters(in: .whitespaces).isEmpty
        let total = affinities.values.reduce(0, +)
        return hasName && abs(total - 1) <= 0.02
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsed = affinities.compactMap { key, value -> StatAffinity? in
            value > 0 ? StatAffinity(stat: key, weight: value) : nil
        }
        onSave(
            OnboardingSkillDraft(
                name: trimmed,
                iconName: iconName,
                colorHex: colorHex,
                categories: Array(selectedCategories),
                affinities: parsed
            )
        )
        dismiss()
    }
}
