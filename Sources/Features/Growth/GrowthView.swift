import SwiftUI

struct GrowthView: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case skills, habits
        var id: String { rawValue }
        var title: String { self == .skills ? "技能" : "习惯" }
    }

    @State private var tab: Tab = .skills
    @State private var isPresentingSkillEditor = false
    @State private var isPresentingHabitEditor = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("视角", selection: $tab) {
                    ForEach(Tab.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                Group {
                    switch tab {
                    case .skills: SkillListView(isPresentingEditor: $isPresentingSkillEditor)
                    case .habits: HabitListView(isPresentingEditor: $isPresentingHabitEditor)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("成长")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
