import SwiftUI

struct GrowthView: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case stats, skills, habits
        var id: String { rawValue }
        var title: String {
            switch self {
            case .stats: return L10n.t("growth.stats")
            case .skills: return L10n.t("growth.skills")
            case .habits: return L10n.t("growth.habits")
            }
        }
    }

    @Environment(GameStore.self) private var store
    @State private var tab: Tab = .stats
    @State private var isPresentingSkillEditor = false
    @State private var isPresentingHabitEditor = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker(L10n.t("growth.view"), selection: $tab) {
                    ForEach(Tab.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                Group {
                    switch tab {
                    case .stats: StatBoardView()
                    case .skills: SkillListView(isPresentingEditor: $isPresentingSkillEditor)
                    case .habits: HabitListView(isPresentingEditor: $isPresentingHabitEditor)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(L10n.t("growth.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if tab != .stats {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            if tab == .skills {
                                isPresentingSkillEditor = true
                            } else {
                                isPresentingHabitEditor = true
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                        .disabled(tab == .skills && !store.canLearnSkill)
                    }
                }
            }
            .sheet(isPresented: $isPresentingSkillEditor) {
                SkillEditorView()
            }
            .sheet(isPresented: $isPresentingHabitEditor) {
                HabitEditorView()
            }
        }
    }
}
