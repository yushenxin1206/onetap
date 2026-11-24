import AppIntents
import UIKit

// MARK: - 打开轻启

/// 「打开轻启」：不带参数，执行即回到 App。
struct OpenOneTapIntent: AppIntent {
    static let title: LocalizedStringResource = "打开轻启"
    static let description = IntentDescription("打开轻启，从首页或快捷列表里选一条入口。")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}

// MARK: - 运行某条快捷

/// 「运行一条快捷」：参数从用户已保存的快捷里点选，执行等同于点击小组件。
struct RunShortcutIntent: AppIntent {
    static let title: LocalizedStringResource = "运行一条快捷"
    static let description = IntentDescription("在轻启里运行一条已保存的快捷。")
    static let openAppWhenRun = true

    @Parameter(title: "快捷")
    var shortcut: ShortcutEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let item = ShortcutEntity.lookup(id: shortcut.id) else {
            return .result(dialog: "这条快捷已经被删除，打开轻启重新选一条。")
        }
        guard let url = URL(string: "onetap://run/\(item.id)") else {
            return .result(dialog: "链接生成失败，请打开轻启重试。")
        }
        _ = await UIApplication.shared.open(url)
        return .result(dialog: "正在运行「\(item.title)」")
    }
}

// MARK: - 快捷实体与查询

/// 动作库里的可选快捷。只读取 App Group 里的快捷列表，不依赖 App 正在运行。
struct ShortcutEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "快捷"
    static var defaultQuery = ShortcutQuery()

    let id: String
    let title: String
    let appName: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: appName.isEmpty ? nil : "\(appName)"
        )
    }

    /// 按 id 回查当前列表，删掉的快捷返回 nil。
    static func lookup(id: String) -> ShortcutEntity? {
        all().first { $0.id == id }
    }

    static func all() -> [ShortcutEntity] {
        let shortcuts = OneTapShared.loadShortcuts() ?? []
        let appNames = Dictionary(
            uniqueKeysWithValues: (OneTapShared.loadSnapshot()?.shortcuts ?? [])
                .map { ($0.id.uuidString, $0.appName) }
        )
        return shortcuts.map {
            ShortcutEntity(
                id: $0.id.uuidString,
                title: $0.title,
                appName: appNames[$0.id.uuidString] ?? ""
            )
        }
    }
}

struct ShortcutQuery: EntityQuery {
    func entities(for identifiers: [ShortcutEntity.ID]) async throws -> [ShortcutEntity] {
        ShortcutEntity.all().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ShortcutEntity] {
        Array(ShortcutEntity.all().prefix(8))
    }

    func defaultResult() async -> ShortcutEntity? {
        ShortcutEntity.all().first
    }
}

// MARK: - 动作库注册

struct OneTapShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenOneTapIntent(),
            phrases: [
                "打开 \(.applicationName)",
                "启动 \(.applicationName)"
            ],
            shortTitle: "打开轻启",
            systemImageName: "bolt.fill"
        )

        AppShortcut(
            intent: RunShortcutIntent(),
            phrases: [
                "用 \(.applicationName) 运行 \(\.$shortcut)",
                "\(.applicationName) 快捷 \(\.$shortcut)"
            ],
            shortTitle: "运行快捷",
            systemImageName: "bolt.horizontal.fill"
        )
    }
}
