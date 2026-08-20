import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(GameStore.self) private var store

    @State private var exportedFile: URL?
    @State private var isImporting = false
    @State private var message: String?

    var body: some View {
        let settings = store.settings

        Form {
            Section("外观") {
                Picker("主题模式", selection: Binding(
                    get: { settings.appearance },
                    set: { settings.appearance = $0; store.save() }
                )) {
                    ForEach(AppearanceMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                Toggle("RPG 风格界面", isOn: Binding(
                    get: { settings.useRPGTheme },
                    set: { settings.useRPGTheme = $0; store.save() }
                ))
                NavigationLink {
                    ShopView()
                } label: {
                    LabeledContent("配色主题", value: currentThemeName)
                }
            }

            Section {
                Picker("一天从几点开始", selection: Binding(
                    get: { settings.dayStartHour },
                    set: { store.updateDayStartHour($0) }
                )) {
                    ForEach(0...8, id: \.self) { hour in
                        Text(String(format: "%02d:00", hour)).tag(hour)
                    }
                }
                Toggle("未完成的任务自动顺延", isOn: Binding(
                    get: { settings.carryOverUnfinished },
                    set: { settings.carryOverUnfinished = $0; store.save() }
                ))
            } header: {
                Text("时间")
            } footer: {
                Text("设为凌晨 4 点时，凌晨 1 点完成的任务仍然算作前一天。这个值会直接改变连续天数的统计口径，中途修改可能让某些连续记录看起来发生跳变。")
            }

            Section("通知") {
                Toggle("启用本地通知", isOn: Binding(
                    get: { settings.notificationsEnabled },
                    set: { settings.notificationsEnabled = $0; store.save(); store.syncNotifications() }
                ))
                Toggle("明日规划提醒", isOn: Binding(
                    get: { settings.planningReminderEnabled },
                    set: { settings.planningReminderEnabled = $0; store.save(); store.syncNotifications() }
                ))
                if settings.planningReminderEnabled {
                    DatePicker(
                        "提醒时间",
                        selection: Binding(
                            get: { time(hour: settings.planningReminderHour, minute: settings.planningReminderMinute) },
                            set: { newValue in
                                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                                settings.planningReminderHour = components.hour ?? 21
                                settings.planningReminderMinute = components.minute ?? 0
                                store.save()
                                store.syncNotifications()
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                }
                Toggle("睡觉提醒", isOn: Binding(
                    get: { settings.bedtimeReminderEnabled },
                    set: { settings.bedtimeReminderEnabled = $0; store.save(); store.syncNotifications() }
                ))
                if settings.bedtimeReminderEnabled {
                    DatePicker(
                        "睡觉时间",
                        selection: Binding(
                            get: { time(hour: settings.bedtimeReminderHour, minute: settings.bedtimeReminderMinute) },
                            set: { newValue in
                                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                                settings.bedtimeReminderHour = components.hour ?? 23
                                settings.bedtimeReminderMinute = components.minute ?? 30
                                store.save()
                                store.syncNotifications()
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                }
                Button("请求通知权限") {
                    Task {
                        await store.container.notifications.requestAuthorization()
                        store.syncNotifications()
                    }
                }
            }

            Section {
                Button("导出完整备份（JSON）") { export { try store.container.export.makeBackup() } }
                Button("导出任务（CSV）") { export { try store.container.export.exportQuestsCSV() } }
                Button("导出每日统计（CSV）") { export { try store.container.export.exportDailyRecordsCSV() } }
                Button("导出成长报告（PDF）") {
                    export { try store.container.export.exportSummaryPDF(player: store.player) }
                }
                Button("从备份恢复") { isImporting = true }
                    .foregroundStyle(.orange)
            } header: {
                Text("数据")
            } footer: {
                Text("恢复会先清空当前全部数据再写入备份内容，操作不可撤销。建议先导出一份当前备份。")
            }

            if !store.container.config.loadIssues.isEmpty {
                Section("配置诊断") {
                    ForEach(store.container.config.loadIssues, id: \.self) { issue in
                        Text(issue)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section("关于") {
                LabeledContent("平衡表版本", value: "\(store.container.config.balance.version)")
                LabeledContent("规则数量", value: "\(store.container.config.unlocks.rules.count)")
                LabeledContent("运行模式", value: store.container.isRunningInMemory ? "内存（数据不会保留）" : "本地持久化")
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: Binding(
            get: { exportedFile.map(ExportedFile.init) },
            set: { if $0 == nil { exportedFile = nil } }
        )) { file in
            ShareSheet(url: file.url)
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                restore(from: url)
            case .failure(let error):
                message = error.localizedDescription
            }
        }
        .alert("提示", isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button("好", role: .cancel) { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    private var currentThemeName: String {
        store.container.config.shop.item(id: store.player.currentThemeID)?.name ?? "默认"
    }

    private func time(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: max(0, min(23, hour)), minute: minute, second: 0, of: Date()) ?? Date()
    }

    private func export(_ make: () throws -> URL) {
        do {
            exportedFile = try make()
        } catch {
            message = "导出失败：\(error.localizedDescription)"
        }
    }

    private func restore(from url: URL) {
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
        do {
            try store.container.export.restore(from: url)
            store.refresh()
            message = "恢复完成"
        } catch {
            message = "恢复失败：\(error.localizedDescription)"
        }
    }
}

private struct ExportedFile: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
