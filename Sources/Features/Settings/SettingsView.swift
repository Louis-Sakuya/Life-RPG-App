import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(GameStore.self) private var store

    @State private var exportedFile: URL?
    @State private var isImporting = false
    @State private var message: String?
    @State private var confirmReset = false

    var body: some View {
        let settings = store.settings

        Form {
            Section {
                Picker(L10n.t("settings.language"), selection: Binding(
                    get: { settings.language },
                    set: { store.updateLanguage($0) }
                )) {
                    ForEach(AppLanguage.allCases) { Text($0.displayName).tag($0) }
                }
            } header: {
                Text(L10n.t("settings.language"))
            } footer: {
                Text(L10n.t("settings.language_footer"))
            }

            Section(L10n.t("settings.appearance")) {
                Picker(L10n.t("settings.theme_mode"), selection: Binding(
                    get: { settings.appearance },
                    set: { settings.appearance = $0; store.save() }
                )) {
                    ForEach(AppearanceMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                Toggle(L10n.t("settings.rpg_ui"), isOn: Binding(
                    get: { settings.useRPGTheme },
                    set: { settings.useRPGTheme = $0; store.save() }
                ))
                NavigationLink {
                    ShopView()
                } label: {
                    LabeledContent(L10n.t("settings.color_theme"), value: currentThemeName)
                }
            }

            Section {
                Picker(L10n.t("settings.day_start"), selection: Binding(
                    get: { settings.dayStartHour },
                    set: { store.updateDayStartHour($0) }
                )) {
                    ForEach(0...8, id: \.self) { hour in
                        Text(String(format: "%02d:00", hour)).tag(hour)
                    }
                }
                Toggle(L10n.t("settings.carry_over"), isOn: Binding(
                    get: { settings.carryOverUnfinished },
                    set: { settings.carryOverUnfinished = $0; store.save() }
                ))
            } header: {
                Text(L10n.t("settings.time"))
            } footer: {
                Text(L10n.t("settings.time_footer"))
            }

            Section {
                Toggle(L10n.t("settings.enable_notifications"), isOn: Binding(
                    get: { settings.notificationsEnabled },
                    set: { settings.notificationsEnabled = $0; store.save(); store.syncNotifications() }
                ))
                Button(L10n.t("settings.request_permission")) {
                    Task {
                        await store.container.notifications.requestAuthorization()
                        store.syncNotifications()
                    }
                }
            } header: {
                Text(L10n.t("settings.notifications"))
            } footer: {
                Text(L10n.t("settings.notifications_footer"))
            }

            Section {
                Button(L10n.t("settings.export_backup")) { export { try store.container.export.makeBackup() } }
                Button(L10n.t("settings.export_quests")) { export { try store.container.export.exportQuestsCSV() } }
                Button(L10n.t("settings.export_daily")) { export { try store.container.export.exportDailyRecordsCSV() } }
                Button(L10n.t("settings.export_pdf")) {
                    export { try store.container.export.exportSummaryPDF(player: store.player) }
                }
                Button(L10n.t("settings.restore")) { isImporting = true }
                    .foregroundStyle(.orange)
            } header: {
                Text(L10n.t("settings.data"))
            } footer: {
                Text(L10n.t("settings.data_footer"))
            }

            Section {
                Toggle(L10n.t("settings.shop_sandbox"), isOn: Binding(
                    get: { store.isTestShopSandboxEnabled },
                    set: { store.setTestShopSandbox($0) }
                ))
            } header: {
                Text(L10n.t("settings.testing"))
            } footer: {
                Text(L10n.t("settings.shop_sandbox_footer"))
            }

            Section {
                Button(L10n.t("settings.reset"), role: .destructive) {
                    confirmReset = true
                }
            } header: {
                Text(L10n.t("settings.account"))
            } footer: {
                Text(L10n.t("settings.reset_footer"))
            }

            if !store.container.config.loadIssues.isEmpty {
                Section(L10n.t("settings.diagnostics")) {
                    ForEach(store.container.config.loadIssues, id: \.self) { issue in
                        Text(issue)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section(L10n.t("settings.about")) {
                LabeledContent(L10n.t("settings.balance_version"), value: "\(store.container.config.balance.version)")
                LabeledContent(L10n.t("settings.rule_count"), value: "\(store.container.config.unlocks.rules.count)")
                LabeledContent(
                    L10n.t("settings.runtime"),
                    value: store.container.isRunningInMemory ? L10n.t("settings.runtime.memory") : L10n.t("settings.runtime.disk")
                )
            }
        }
        .navigationTitle(L10n.t("settings.title"))
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
        .alert(L10n.t("common.notice"), isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button(L10n.t("common.ok"), role: .cancel) { message = nil }
        } message: {
            Text(message ?? "")
        }
        .alert(L10n.t("settings.reset.title"), isPresented: $confirmReset) {
            Button(L10n.t("common.cancel"), role: .cancel) {}
            Button(L10n.t("settings.reset.confirm"), role: .destructive) {
                store.requestAccountReset()
            }
        } message: {
            Text(L10n.t("settings.reset.message"))
        }
    }

    private var currentThemeName: String {
        store.container.config.shop.item(id: store.player.currentThemeID)?.localizedName ?? L10n.t("settings.default_theme")
    }

    private func export(_ make: () throws -> URL) {
        do {
            exportedFile = try make()
        } catch {
            message = L10n.format("settings.export_failed", error.localizedDescription)
        }
    }

    private func restore(from url: URL) {
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
        do {
            try store.container.export.restore(from: url)
            store.reloadAfterRestore()
            message = L10n.t("settings.restore_ok")
        } catch {
            message = L10n.format("settings.restore_failed", error.localizedDescription)
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
