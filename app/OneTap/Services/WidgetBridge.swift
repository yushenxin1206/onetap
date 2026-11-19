import Foundation
import WidgetKit

/// 宿主把"能展示什么"压成快照写进 App Group。
/// 小组件只负责展示和把 onetap:// 交回宿主，执行仍然只有一套。
@MainActor
enum WidgetBridge {
    static func publish(store: ShortcutStore, catalog: CatalogStore) {
        let items: [WidgetShortcut] = store.shortcuts.compactMap { shortcut in
            guard
                let app = catalog.app(id: shortcut.appID),
                catalog.action(appID: shortcut.appID, actionID: shortcut.actionID) != nil
            else { return nil }

            return WidgetShortcut(
                id: shortcut.id,
                title: shortcut.title,
                appName: app.name,
                glyph: app.glyph,
                tint: app.tint
            )
        }

        OneTapShared.saveSnapshot(WidgetSnapshot(shortcuts: items))
        WidgetCenter.shared.reloadAllTimelines()
    }
}
