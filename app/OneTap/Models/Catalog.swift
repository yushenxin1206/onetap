import Foundation

/// 唯一的能力目录。内置清单只在首次安装时铺进来，之后这份目录就是唯一事实。
struct CatalogData: Codable {
    static let currentSchema = 2

    var schema: Int
    var apps: [CapabilityApp]
}

@MainActor
final class CatalogStore: ObservableObject {
    static let shared = CatalogStore()

    private static let storageKey = "onetap.catalog.v1"
    /// 上一版的自定义目录，迁移后立即删除。
    private static let legacyKey = "onetap.custom.catalog.v1"

    @Published private(set) var apps: [CapabilityApp] = []

    init() {
        if
            let data = OneTapShared.defaults.data(forKey: Self.storageKey),
            let decoded = try? JSONDecoder().decode(CatalogData.self, from: data),
            decoded.schema == CatalogData.currentSchema
        {
            apps = decoded.apps
            Self.cleanupLegacyKeys()
            refreshBuiltInTaglinesIfNeeded()
            return
        }

        if
            let data = OneTapShared.defaults.data(forKey: Self.storageKey),
            let legacy = try? JSONDecoder().decode(LegacyCatalog.self, from: data)
        {
            let migration = Self.migrate(legacy)
            apps = migration.apps
            if persist() {
                for record in migration.records {
                    RunLogStore.shared.importLegacy(
                        appID: record.appID,
                        actionID: record.actionID,
                        result: record.result
                    )
                }
                Self.cleanupLegacyKeys()
            }
            refreshBuiltInTaglinesIfNeeded()
            return
        }

        // 既没有新目录、也没有可读的旧目录：用内置清单铺底。
        apps = Self.seedApps()
        if persist() { Self.cleanupLegacyKeys() }
    }

    // MARK: - 查询

    /// 把内置 App 里仍是历史默认文案的 tagline 清空，交给界面按入口数派生。
    /// 用户自己填过的文案不动，也不重建目录、快捷或运行记录。
    private func refreshBuiltInTaglinesIfNeeded() {
        let key = "onetap.tagline.version"
        guard OneTapShared.defaults.integer(forKey: key) < 2 else { return }

        let legacyTaglines: [String: Set<String>] = [
            "wechat": [
                "扫一扫有非公开入口，付款码没有可靠入口已移除",
                "直接打开微信扫一扫"
            ],
            "alipay": [
                "扫一扫、付款码、乘车码均有社区入口",
                "扫一扫、付款码、乘车码"
            ],
            "qqmusic": [
                "只保留打开 App 的入口",
                "直接打开 QQ 音乐"
            ]
        ]

        var changed = false
        for index in apps.indices {
            guard
                let legacy = legacyTaglines[apps[index].id],
                legacy.contains(apps[index].tagline)
            else { continue }
            apps[index].tagline = ""
            changed = true
        }
        if changed { _ = persist() }
        OneTapShared.defaults.set(2, forKey: key)
    }

    func app(id: String) -> CapabilityApp? {
        apps.first { $0.id == id }
    }

    func action(appID: String, actionID: String) -> CapabilityAction? {
        app(id: appID)?.actions.first { $0.id == actionID }
    }

    var actionCount: Int {
        apps.reduce(0) { $0 + $1.actions.count }
    }

    // MARK: - App

    @discardableResult
    func addApp(name: String, tagline: String, glyph: String, tint: String) -> CapabilityApp {
        let app = CapabilityApp(
            id: "app.\(UUID().uuidString)",
            name: name,
            tagline: tagline,
            glyph: glyph,
            tint: tint,
            scheme: nil,
            actions: []
        )
        apps.append(app)
        persist()
        return app
    }

    func updateApp(id: String, name: String, tagline: String, glyph: String, tint: String) {
        guard let index = apps.firstIndex(where: { $0.id == id }) else { return }
        apps[index].name = name
        apps[index].tagline = tagline
        apps[index].glyph = glyph
        apps[index].tint = tint
        persist()
    }

    func deleteApp(id: String) {
        apps.removeAll { $0.id == id }
        RunLogStore.shared.clear(appID: id)
        persist()
    }

    // MARK: - 动作

    func addAction(appID: String, action: CapabilityAction) {
        guard let index = apps.firstIndex(where: { $0.id == appID }) else { return }
        apps[index].actions.append(action)
        persist()
    }

    func updateAction(appID: String, action: CapabilityAction) {
        guard
            let appIndex = apps.firstIndex(where: { $0.id == appID }),
            let actionIndex = apps[appIndex].actions.firstIndex(where: { $0.id == action.id })
        else { return }

        let previous = apps[appIndex].actions[actionIndex]
        if previous.normalizedURL != action.normalizedURL || previous.shortcutName != action.shortcutName {
            RunLogStore.shared.clear(appID: appID, actionID: action.id)
        }
        apps[appIndex].actions[actionIndex] = action
        persist()
    }

    func deleteAction(appID: String, actionID: String) {
        guard let index = apps.firstIndex(where: { $0.id == appID }) else { return }
        apps[index].actions.removeAll { $0.id == actionID }
        RunLogStore.shared.clear(appID: appID, actionID: actionID)
        persist()
    }

    // MARK: - 首次铺底

    private static func seedApps() -> [CapabilityApp] {
        var seeded = normalized(bundledApps())
        let existing = Set(seeded.map(\.id))

        if
            let data = OneTapShared.defaults.data(forKey: legacyKey),
            let legacy = try? JSONDecoder().decode(LegacyCatalog.self, from: data)
        {
            for app in migrate(legacy).apps where !existing.contains(app.id) {
                seeded.append(app)
            }
        }
        return seeded
    }

    static func bundledApps() -> [CapabilityApp] {
        guard
            let url = Bundle.main.url(forResource: "capabilities", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let manifest = try? JSONDecoder().decode(CapabilityManifest.self, from: data)
        else { return [] }
        return manifest.apps
    }

    // MARK: - 旧数据迁移

    private struct LegacyCatalog: Codable {
        var apps: [LegacyApp]
    }

    private struct LegacyApp: Codable {
        var id: String
        var name: String
        var tagline: String
        var glyph: String
        var tint: String
        var scheme: String?
        var actions: [LegacyAction]
    }

    private struct LegacyAction: Codable {
        var id: String
        var title: String
        var subtitle: String?
        var url: String?
        var universalLink: String?
        var schemeURL: String?
        var webURL: String?
        var shortcutName: String?
        var verification: String?
    }

    private struct Migration {
        var apps: [CapabilityApp]
        var records: [(appID: String, actionID: String, result: RunResult)]
    }

    private static func migrate(_ legacy: LegacyCatalog) -> Migration {
        var records: [(String, String, RunResult)] = []
        var apps: [CapabilityApp] = []

        for oldApp in legacy.apps {
            let scheme = trimmed(oldApp.scheme)
            let root = scheme.map { "\($0)://" }

            var actions = oldApp.actions.map { oldAction -> CapabilityAction in
                let merged = [oldAction.universalLink, oldAction.schemeURL, oldAction.webURL, oldAction.url]
                    .compactMap { trimmed($0) }
                    .first
                let shortcut = trimmed(oldAction.shortcutName)

                var url = merged
                if url == nil && shortcut == nil { url = root }

                if let raw = oldAction.verification,
                   let result = legacyResult(raw) {
                    records.append((oldApp.id, oldAction.id, result))
                }

                return CapabilityAction(
                    id: oldAction.id,
                    title: oldAction.title,
                    subtitle: trimmed(oldAction.subtitle),
                    url: url,
                    shortcutName: url == nil ? shortcut : nil
                )
            }

            if let root, !actions.contains(where: { isOpenAction($0, root: root) }) {
                actions.append(
                    CapabilityAction(
                        id: uniqueOpenID(in: actions),
                        title: openTitle(for: oldApp.name),
                        subtitle: "直接进入首页",
                        url: root,
                        shortcutName: nil
                    )
                )
            }

            apps.append(
                CapabilityApp(
                    id: oldApp.id,
                    name: oldApp.name,
                    tagline: oldApp.tagline,
                    glyph: oldApp.glyph,
                    tint: oldApp.tint,
                    scheme: scheme,
                    actions: actions
                )
            )
        }

        return Migration(apps: apps, records: records.map { (appID: $0.0, actionID: $0.1, result: $0.2) })
    }

    private static func legacyResult(_ raw: String) -> RunResult? {
        switch raw {
        case "reachable": return .reachable
        case "unreachable": return .unreachable
        default: return nil
        }
    }

    /// 保证有 scheme 的 App 至少有一条标题为「打开 XX」的首页动作。
    private static func normalized(_ apps: [CapabilityApp]) -> [CapabilityApp] {
        apps.map { app in
            var app = app
            guard
                let root = app.rootURL,
                !app.actions.contains(where: { isOpenAction($0, root: root) })
            else { return app }
            app.actions.append(
                CapabilityAction(
                    id: uniqueOpenID(in: app.actions),
                    title: openTitle(for: app.name),
                    subtitle: "直接进入首页",
                    url: root,
                    shortcutName: nil
                )
            )
            return app
        }
    }

    private static func isOpenAction(_ action: CapabilityAction, root: String) -> Bool {
        action.title.hasPrefix("打开") && action.normalizedURL?.lowercased() == root.lowercased()
    }

    private static func openTitle(for name: String) -> String {
        guard let first = name.first else { return "打开" }
        return first.isASCII ? "打开 \(name)" : "打开\(name)"
    }

    private static func uniqueOpenID(in actions: [CapabilityAction]) -> String {
        let ids = Set(actions.map(\.id))
        if !ids.contains("open") { return "open" }
        var index = 2
        while ids.contains("open-\(index)") { index += 1 }
        return "open-\(index)"
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        return raw
    }

    private static func cleanupLegacyKeys() {
        OneTapShared.defaults.removeObject(forKey: legacyKey)
    }

    // MARK: - 持久化

    /// 先编码并回读校验，成功后才允许落盘。
    static func preparedData(for apps: [CapabilityApp]) -> Data? {
        let payload = CatalogData(schema: CatalogData.currentSchema, apps: apps)
        guard
            let data = try? JSONEncoder().encode(payload),
            let check = try? JSONDecoder().decode(CatalogData.self, from: data),
            check.schema == CatalogData.currentSchema
        else { return nil }
        return data
    }

    @discardableResult
    func commit(_ data: Data) -> Bool {
        guard
            let decoded = try? JSONDecoder().decode(CatalogData.self, from: data),
            decoded.schema == CatalogData.currentSchema
        else { return false }
        OneTapShared.defaults.set(data, forKey: Self.storageKey)
        apps = decoded.apps
        return true
    }

    @discardableResult
    private func persist() -> Bool {
        guard let data = Self.preparedData(for: apps) else { return false }
        return commit(data)
    }
}
