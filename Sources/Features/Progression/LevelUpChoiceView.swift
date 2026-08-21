import SwiftUI

struct LevelUpChoiceView: View {
    enum Stage {
        case pick
        case allocateStat
        case slotFollowUp
    }

    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette

    var event: LevelUpEvent
    var initialStage: Stage = .pick

    @State private var stage: Stage = .pick
    @State private var isPresentingSkillEditor = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    switch stage {
                    case .pick: pickCards
                    case .allocateStat: statGrid
                    case .slotFollowUp: slotFollowUp
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(L10n.format("levelup.title", event.level))
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled()
            .onAppear { stage = initialStage }
            .sheet(isPresented: $isPresentingSkillEditor) {
                SkillEditorView()
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(Circle().fill(palette.gradient))
            Text(L10n.format("celebrate.level_up", event.level))
                .font(.title2.weight(.bold))
            if event.goldReward > 0 {
                Text(L10n.format("celebrate.gold", event.goldReward))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(hex: "#D4A017"))
            } else {
                Text(L10n.t("levelup.gold_already"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(L10n.t("levelup.subtitle"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var pickCards: some View {
        VStack(spacing: 12) {
            choiceCard(
                icon: "chart.bar.fill",
                title: L10n.t("levelup.choice.stat"),
                detail: L10n.t("levelup.choice.stat_detail"),
                tint: Color(hex: "#5B8DEF")
            ) {
                withAnimation { stage = .allocateStat }
            }
            choiceCard(
                icon: "square.grid.3x3.fill",
                title: L10n.t("levelup.choice.slot"),
                detail: L10n.format("levelup.choice.slot_detail", store.skillSlotCap + 1),
                tint: Color(hex: "#C9A227")
            ) {
                store.claimLevelUpSkillSlot()
            }
        }
    }

    private var statGrid: some View {
        VStack(spacing: 12) {
            ForEach(CoreStatID.allCases) { stat in
                Button {
                    store.claimLevelUpStatBonus(stat)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: stat.iconName)
                            .foregroundStyle(Color(hex: stat.colorHex))
                            .frame(width: 36, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(hex: stat.colorHex).opacity(0.16))
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stat.title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(L10n.format("levelup.stat.current", store.effectiveStatLevel(stat)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("+1")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color(hex: stat.colorHex))
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                }
                .buttonStyle(.plain)
            }

            Button(L10n.t("common.back")) {
                withAnimation { stage = .pick }
            }
            .padding(.top, 4)
        }
    }

    private var slotFollowUp: some View {
        VStack(spacing: 14) {
            Text(L10n.format("levelup.slot.unlocked", store.skillSlotCap))
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(L10n.t("levelup.slot.followup"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                isPresentingSkillEditor = true
            } label: {
                Text(L10n.t("levelup.slot.learn_now"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(palette.accent)
            .disabled(!store.canLearnSkill)

            Button {
                store.dismissSkillSlotFollowUp()
            } label: {
                Text(L10n.t("levelup.slot.later"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.bordered)
        }
    }

    private func choiceCard(icon: String, title: String, detail: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
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
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
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