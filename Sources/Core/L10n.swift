import Foundation

/// 应用内语言。`system` 跟随设备；不是英语时默认中文，因为产品文案最初就是中文。
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case chinese = "zh-Hans"
    case english = "en"

    var id: String { rawValue }

    var resolvedCode: String {
        switch self {
        case .chinese: return "zh-Hans"
        case .english: return "en"
        case .system:
            let preferred = Locale.preferredLanguages.first?.lowercased() ?? ""
            if preferred.hasPrefix("en") { return "en" }
            return "zh-Hans"
        }
    }

    var locale: Locale {
        resolvedCode == "en" ? Locale(identifier: "en_US") : Locale(identifier: "zh_CN")
    }

    var displayName: String {
        switch self {
        case .system: return L10n.t("language.system")
        case .chinese: return L10n.t("language.chinese")
        case .english: return L10n.t("language.english")
        }
    }
}

/// 运行时本地化。语言表是 JSON，不走系统 `Localizable.strings`，
/// 这样设置页切换语言不必重启，也不依赖 Xcode 的 lproj 结构。
enum L10n {
    private static let lock = NSLock()
    private static var languageStorage: AppLanguage = .system
    private static var tables: [String: [String: String]] = [:]
    private static var didLoad = false

    static var language: AppLanguage {
        get {
            lock.lock()
            defer { lock.unlock() }
            return languageStorage
        }
        set {
            lock.lock()
            languageStorage = newValue
            lock.unlock()
        }
    }

    static var locale: Locale { language.locale }

    static var isEnglish: Bool { language.resolvedCode == "en" }

    static func bootstrap(bundle: Bundle = .main) {
        lock.lock()
        tables["zh-Hans"] = loadTable("zh-Hans", bundle: bundle)
        tables["en"] = loadTable("en", bundle: bundle)
        didLoad = true
        lock.unlock()
    }

    static func t(_ key: String, fallback: String? = nil) -> String {
        ensureLoaded()
        let code = language.resolvedCode
        if let value = lookup(key, code: code) { return value }
        if code != "zh-Hans", let value = lookup(key, code: "zh-Hans") { return value }
        return fallback ?? key
    }

    static func format(_ key: String, _ args: CVarArg...) -> String {
        String(format: t(key), locale: locale, arguments: args)
    }

    static func weekdayShort(_ weekday: Int) -> String {
        t("weekday.short.\(weekday)")
    }

    static func table(for code: String) -> [String: String] {
        ensureLoaded()
        lock.lock()
        defer { lock.unlock() }
        return tables[code] ?? [:]
    }

    // MARK: - 私有

    private static func ensureLoaded() {
        lock.lock()
        let loaded = didLoad
        lock.unlock()
        if !loaded {
            bootstrap()
        }
    }

    private static func lookup(_ key: String, code: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return tables[code]?[key]
    }

    private static let searchDirectories: [String?] = [nil, "Localization", "Resources/Localization", "Resources"]

    private static func loadTable(_ name: String, bundle: Bundle) -> [String: String] {
        guard let url = locate(name, bundle: bundle) else { return [:] }
        guard let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }

    private static func locate(_ name: String, bundle: Bundle) -> URL? {
        for directory in searchDirectories {
            if let url = bundle.url(forResource: name, withExtension: "json", subdirectory: directory) {
                return url
            }
        }
        return nil
    }
}
