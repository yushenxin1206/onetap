import Foundation
import AppIntents

@MainActor
final class ShortcutStore: ObservableObject {
    static let shared = ShortcutStore()

    @Published private(set) var shortcuts: [Shortcut] = []

    init() {
        if let decoded = OneTapShared.loadShortcuts() {
            shortcuts = decoded
        } else if
            let legacy = UserDefaults.standard.data(forKey: OneTapShared.shortcutsKey),
            let decoded = try? JSONDecoder().decode([Shortcut].self, from: legacy)
        {
            // 从上一版 App 自己的容器迁移到 App Group，避免升级后丢快捷。
            shortcuts = decoded
            persist()
        } else {
            shortcuts = Self.seed
            persist()
        }
        // 旧副本迁移完就删，重复执行也安全。
        UserDefaults.standard.removeObject(forKey: OneTapShared.shortcutsKey)
    }

    var hero: Shortcut? { shortcuts.first }

    var tiles: [Shortcut] { Array(shortcuts.dropFirst()) }

    func add(_ shortcut: Shortcut) {
        shortcuts.append(shortcut)
        persist()
    }

    /// 拖动排序：顺序就是首页 Hero 与格子的展示顺序。
    func move(from source: IndexSet, to destination: Int) {
        var items = shortcuts
        let moving = source.map { items[$0] }
        for index in source.sorted(by: >) {
            items.remove(at: index)
        }
        let adjusted = destination - source.filter { $0 < destination }.count
        items.insert(contentsOf: moving, at: min(max(adjusted, 0), items.count))
        shortcuts = items
        persist()
    }

    func rename(id: UUID, title: String) {
        guard let index = shortcuts.firstIndex(where: { $0.id == id }) else { return }
        shortcuts[index].title = title
        persist()
    }

    /// 删掉引用了被删除 App / 动作的快捷，避免留下指向空目标的条目。
    @discardableResult
    func removeShortcuts(appID: String) -> Int {
        let before = shortcuts.count
        shortcuts.removeAll { $0.appID == appID }
        let removed = before - shortcuts.count
        if removed > 0 { persist() }
        return removed
    }

    @discardableResult
    func removeShortcuts(appID: String, actionID: String) -> Int {
        let before = shortcuts.count
        shortcuts.removeAll { $0.appID == appID && $0.actionID == actionID }
        let removed = before - shortcuts.count
        if removed > 0 { persist() }
        return removed
    }

    func countShortcuts(appID: String, actionID: String? = nil) -> Int {
        shortcuts.filter {
            $0.appID == appID && (actionID == nil || $0.actionID == actionID)
        }.count
    }

    static func preparedData(for shortcuts: [Shortcut]) -> Data? {
        try? JSONEncoder().encode(shortcuts)
    }

    @discardableResult
    func commit(_ data: Data) -> Bool {
        guard let decoded = try? JSONDecoder().decode([Shortcut].self, from: data) else {
            return false
        }
        OneTapShared.defaults.set(data, forKey: OneTapShared.shortcutsKey)
        shortcuts = decoded
        // 新增、改名、删除、排序后都走这里，刷新动作库里的快捷候选。
        OneTapShortcuts.updateAppShortcutParameters()
        return true
    }

    private func persist() {
        guard let data = Self.preparedData(for: shortcuts) else { return }
        commit(data)
    }

    /// 首次启动的默认快捷：5 条，顺序即首页 Hero + 格子顺序。
    static let seed: [Shortcut] = [
        Shortcut(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            title: "扫一扫",
            appID: "wechat",
            actionID: "scan"
        ),
        Shortcut(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            title: "扫一扫",
            appID: "alipay",
            actionID: "scan"
        ),
        Shortcut(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            title: "付款码",
            appID: "alipay",
            actionID: "pay"
        ),
        Shortcut(
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
            title: "乘车码",
            appID: "alipay",
            actionID: "ride"
        ),
        Shortcut(
            id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
            title: "打开 QQ 音乐",
            appID: "qqmusic",
            actionID: "open"
        )
    ]
}
