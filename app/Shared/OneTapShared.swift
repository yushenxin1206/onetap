import Foundation

/// App 与小组件扩展共享的数据层。
/// 宿主只负责写快照和快捷列表；扩展只读，不重写执行逻辑。
enum OneTapShared {
    static let appGroupID = "group.app.onetap.launcher"
    static let shortcutsKey = "onetap.shortcuts.v1"
    static let snapshotKey = "onetap.widget.snapshot.v1"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static func loadShortcuts() -> [Shortcut]? {
        guard let data = defaults.data(forKey: shortcutsKey) else { return nil }
        return try? JSONDecoder().decode([Shortcut].self, from: data)
    }

    static func saveShortcuts(_ shortcuts: [Shortcut]) {
        guard let data = try? JSONEncoder().encode(shortcuts) else { return }
        defaults.set(data, forKey: shortcutsKey)
    }

    static func loadSnapshot() -> WidgetSnapshot? {
        guard let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    static func saveSnapshot(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    static func runURL(id: UUID) -> URL {
        URL(string: "onetap://run/\(id.uuidString)")!
    }

    static let homeURL = URL(string: "onetap://")!
}

/// 小组件只拿展示所需的快照，不依赖能力清单解析，也不包含任何执行代码。
struct WidgetShortcut: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let appName: String
    let glyph: String
    let tint: String

    var runURL: URL { OneTapShared.runURL(id: id) }
}

struct WidgetSnapshot: Codable, Hashable {
    var shortcuts: [WidgetShortcut]
}
