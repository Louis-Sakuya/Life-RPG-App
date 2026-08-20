import SwiftUI

struct SkillEditorView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var iconName = "star.fill"
    @State private var colorHex = "#5B8DEF"

    var body: some View {
        NavigationStack {
            Form {
                Section("名称") {
                    TextField("例如 Programming、English、Fitness", text: $name)
                }
                Section("图标") {
                    IconPicker(selection: $iconName, tint: Color(hex: colorHex))
                }
                Section("颜色") {
                    ColorPickerRow(selection: $colorHex)
                }
                Section {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: colorHex).opacity(0.16))
                                .frame(width: 40, height: 40)
                            Image(systemName: iconName)
                                .foregroundStyle(Color(hex: colorHex))
                        }
                        Text(name.isEmpty ? "新技能" : name)
                            .font(.body.weight(.medium))
                        Spacer()
                        Text("Lv1")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color(hex: colorHex))
                    }
                } header: {
                    Text("预览")
                }
            }
            .navigationTitle("新建技能")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        store.createSkill(name: name, iconName: iconName, colorHex: colorHex)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
