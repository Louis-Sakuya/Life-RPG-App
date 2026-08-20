import SwiftUI

struct SkillListView: View {
    @Environment(GameStore.self) private var store
    @Binding var isPresentingEditor: Bool

    var body: some View {
        List {
            if store.skills.isEmpty {
                EmptyStateView(
                    icon: "star.circle",
                    title: "还没有技能",
                    message: "技能可以自由创建：编程、英语、健身、烹饪、绘画……完成任务时把经验分配给它们。",
                    actionTitle: "创建技能",
                    action: { isPresentingEditor = true }
                )
                .listRowBackground(Color.clear)
            }

            ForEach(store.skills) { skill in
                NavigationLink {
                    SkillDetailView(skill: skill)
                } label: {
                    SkillRow(skill: skill, progress: store.skillProgress(skill))
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    store.deleteSkill(store.skills[index])
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct SkillRow: View {
    var skill: Skill
    var progress: LevelProgress

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
                    Text(skill.name)
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
                Text(progress.isMaxLevel ? "已满级" : "\(progress.currentEXP) / \(progress.requiredEXP) EXP")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SkillDetailView: View {
    @Environment(GameStore.self) private var store

    var skill: Skill

    var body: some View {
        let progress = store.skillProgress(skill)
        let tint = Color(hex: skill.colorHex)

        List {
            Section {
                VStack(spacing: 10) {
                    Image(systemName: skill.iconName)
                        .font(.system(size: 40))
                        .foregroundStyle(tint)
                    Text(skill.name)
                        .font(.title3.weight(.semibold))
                    Text("Lv\(progress.level)")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(tint)
                    ProgressBar(
                        value: progress.progress,
                        gradient: LinearGradient(colors: [tint, tint.opacity(0.55)], startPoint: .leading, endPoint: .trailing)
                    )
                    Text(progress.isMaxLevel ? "已满级" : "距离下一级还差 \(progress.remainingEXP) EXP")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section("数据") {
                LabeledContent("总经验", value: "\(skill.totalEXP)")
                LabeledContent("创建于", value: skill.createdAt.formatted(date: .abbreviated, time: .omitted))
            }

            Section {
                Text("完成任务时把经验分配给这个技能，它就会独立成长。同一个任务可以同时喂养多个技能。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(skill.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
