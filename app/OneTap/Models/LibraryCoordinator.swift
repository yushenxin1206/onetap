import Combine
import Foundation

/// 删除与撤销的唯一入口：目录、快捷、运行记录一起算、一起落。
@MainActor
final class LibraryCoordinator: ObservableObject {
    static let shared = LibraryCoordinator()

    struct Undo: Identifiable {
        let id = UUID()
        let message: String
        fileprivate let payload: Payload
    }

    fileprivate struct Payload {
        enum Kind {
            case app(app: CapabilityApp, index: Int)
            case action(appID: String, action: CapabilityAction, index: Int)
            case shortcut(shortcut: Shortcut, index: Int)
        }

        var kind: Kind
        var shortcuts: [(index: Int, shortcut: Shortcut)]
        var records: [RunRecord]
    }

    @Published private(set) var undo: Undo?

    private let catalog = CatalogStore.shared
    private let shortcuts = ShortcutStore.shared
    private let runLog = RunLogStore.shared
    private var cancellables = Set<AnyCancellable>()
    private var isMutating = false

    init() {
        catalog.objectWillChange
            .merge(with: shortcuts.objectWillChange)
            .sink { [weak self] _ in
                guard let self, !self.isMutating else { return }
                self.cancelUndo()
            }
            .store(in: &cancellables)

        installSeedIfNeeded()
        pruneOrphans()
        WidgetBridge.publish(store: shortcuts, catalog: catalog)
    }

    /// 内置清单换代：版本提升时把目录、快捷、运行记录整体重铺，
    /// 已安装设备同样生效；用户自建的 App / 动作 / 快捷会被覆盖。
    private static let seedVersionKey = "onetap.seed.version"
    private static let seedVersion = 3

    private func installSeedIfNeeded() {
        let installed = OneTapShared.defaults.integer(forKey: Self.seedVersionKey)
        guard installed < Self.seedVersion else { return }

        let apps = CatalogStore.bundledApps()
        guard !apps.isEmpty else { return }

        guard
            let catalogData = CatalogStore.preparedData(for: apps),
            let shortcutData = ShortcutStore.preparedData(for: ShortcutStore.seed)
        else { return }

        isMutating = true
        defer { isMutating = false }

        guard catalog.commit(catalogData), shortcuts.commit(shortcutData) else { return }
        runLog.prune(validKeys: [])
        OneTapShared.defaults.set(Self.seedVersion, forKey: Self.seedVersionKey)
        WidgetBridge.publish(store: shortcuts, catalog: catalog)
    }

    func shortcutCount(appID: String, actionID: String? = nil) -> Int {
        shortcuts.countShortcuts(appID: appID, actionID: actionID)
    }

    func undoMessage(for app: CapabilityApp) -> String {
        let count = shortcutCount(appID: app.id)
        return count > 0 ? "已删除「\(app.name)」和 \(count) 条快捷" : "已删除「\(app.name)」"
    }

    func undoMessage(for app: CapabilityApp, action: CapabilityAction) -> String {
        let count = shortcutCount(appID: app.id, actionID: action.id)
        return count > 0 ? "已删除动作「\(action.title)」和 \(count) 条快捷" : "已删除动作「\(action.title)」"
    }

    func undoMessage(for shortcut: Shortcut) -> String {
        "已删除快捷「\(shortcut.title)」"
    }

    // MARK: - 删除

    @discardableResult
    func deleteApp(_ app: CapabilityApp) -> Bool {
        guard let appIndex = catalog.apps.firstIndex(where: { $0.id == app.id }) else { return false }

        cancelUndo()

        let removedShortcuts = shortcuts.shortcuts.enumerated()
            .filter { $0.element.appID == app.id }
            .map { (index: $0.offset, shortcut: $0.element) }
        let removedRecords = runLog.records.filter { $0.appID == app.id }
        let message = undoMessage(for: app)

        var newApps = catalog.apps
        newApps.remove(at: appIndex)
        var newShortcuts = shortcuts.shortcuts
        newShortcuts.removeAll { $0.appID == app.id }

        guard apply(newApps: newApps, newShortcuts: newShortcuts) else { return false }

        runLog.clear(appID: app.id)

        undo = Undo(
            message: message,
            payload: Payload(
                kind: .app(app: app, index: appIndex),
                shortcuts: removedShortcuts,
                records: removedRecords
            )
        )
        scheduleUndoExpiry()
        return true
    }

    @discardableResult
    func deleteAction(appID: String, action: CapabilityAction) -> Bool {
        guard
            let appIndex = catalog.apps.firstIndex(where: { $0.id == appID }),
            let actionIndex = catalog.apps[appIndex].actions.firstIndex(where: { $0.id == action.id })
        else { return false }

        cancelUndo()
        let app = catalog.apps[appIndex]

        let removedShortcuts = shortcuts.shortcuts.enumerated()
            .filter { $0.element.appID == appID && $0.element.actionID == action.id }
            .map { (index: $0.offset, shortcut: $0.element) }
        let removedRecords = runLog.records.filter {
            $0.appID == appID && $0.actionID == action.id
        }
        let message = undoMessage(for: app, action: action)

        var newApps = catalog.apps
        newApps[appIndex].actions.remove(at: actionIndex)
        var newShortcuts = shortcuts.shortcuts
        newShortcuts.removeAll { $0.appID == appID && $0.actionID == action.id }

        guard apply(newApps: newApps, newShortcuts: newShortcuts) else { return false }

        runLog.clear(appID: appID, actionID: action.id)

        undo = Undo(
            message: message,
            payload: Payload(
                kind: .action(appID: appID, action: action, index: actionIndex),
                shortcuts: removedShortcuts,
                records: removedRecords
            )
        )
        scheduleUndoExpiry()
        return true
    }

    // MARK: - 撤销

    /// 删除单条快捷：目录不动，只提交快捷数组；运行记录按动作共享，不清。
    @discardableResult
    func deleteShortcut(_ shortcut: Shortcut) -> Bool {
        guard let index = shortcuts.shortcuts.firstIndex(where: { $0.id == shortcut.id }) else {
            return false
        }

        cancelUndo()
        let message = undoMessage(for: shortcut)

        var newShortcuts = shortcuts.shortcuts
        newShortcuts.remove(at: index)

        guard apply(newApps: catalog.apps, newShortcuts: newShortcuts) else { return false }

        undo = Undo(
            message: message,
            payload: Payload(
                kind: .shortcut(shortcut: shortcut, index: index),
                shortcuts: [],
                records: []
            )
        )
        scheduleUndoExpiry()
        return true
    }

    func undoLastDeletion() {
        guard let undo else { return }
        self.undo = nil

        var newApps = catalog.apps
        var newShortcuts = shortcuts.shortcuts

        switch undo.payload.kind {
        case let .app(app, index):
            newApps.insert(app, at: min(index, newApps.count))
        case let .action(appID, action, index):
            guard let appIndex = newApps.firstIndex(where: { $0.id == appID }) else { return }
            newApps[appIndex].actions.insert(action, at: min(index, newApps[appIndex].actions.count))
        case let .shortcut(shortcut, index):
            newShortcuts.insert(shortcut, at: min(index, newShortcuts.count))
        }

        for entry in undo.payload.shortcuts.sorted(by: { $0.index < $1.index }) {
            newShortcuts.insert(entry.shortcut, at: min(entry.index, newShortcuts.count))
        }

        guard apply(newApps: newApps, newShortcuts: newShortcuts) else { return }
        runLog.restore(undo.payload.records)
    }

    func cancelUndo() {
        undo = nil
    }

    // MARK: - 启动自检

    func pruneOrphans() {
        let validKeys = Set(
            catalog.apps.flatMap { app in
                app.actions.map { "\(app.id)/\($0.id)" }
            }
        )

        let kept = shortcuts.shortcuts.filter {
            validKeys.contains("\($0.appID)/\($0.actionID)")
        }
        if kept.count != shortcuts.shortcuts.count,
           let data = ShortcutStore.preparedData(for: kept) {
            isMutating = true
            shortcuts.commit(data)
            isMutating = false
        }

        runLog.prune(validKeys: validKeys)
        WidgetBridge.publish(store: shortcuts, catalog: catalog)
    }

    // MARK: - 落盘

    /// 两份新数据先都编码成功，再一起提交；任一份准备失败就两份都不写。
    private func apply(newApps: [CapabilityApp], newShortcuts: [Shortcut]) -> Bool {
        guard
            let catalogData = CatalogStore.preparedData(for: newApps),
            let shortcutData = ShortcutStore.preparedData(for: newShortcuts)
        else { return false }

        isMutating = true
        defer { isMutating = false }

        guard catalog.commit(catalogData), shortcuts.commit(shortcutData) else { return false }
        WidgetBridge.publish(store: shortcuts, catalog: catalog)
        return true
    }

    private func scheduleUndoExpiry() {
        guard let id = undo?.id else { return }
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard let self, self.undo?.id == id else { return }
            self.undo = nil
        }
    }
}
