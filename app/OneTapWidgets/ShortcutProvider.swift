import SwiftUI
import WidgetKit

struct ShortcutEntry: TimelineEntry {
    let date: Date
    let shortcuts: [WidgetShortcut]

    var hero: WidgetShortcut? { shortcuts.first }
}

extension ShortcutEntry {
    static let placeholder = ShortcutEntry(
        date: Date(),
        shortcuts: [
            WidgetShortcut(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                title: "轻启快捷",
                appName: "",
                glyph: "bolt.fill",
                tint: "#121211"
            ),
            WidgetShortcut(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                title: "轻启快捷",
                appName: "",
                glyph: "link",
                tint: "#121211"
            ),
            WidgetShortcut(
                id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                title: "轻启快捷",
                appName: "",
                glyph: "star.fill",
                tint: "#121211"
            ),
            WidgetShortcut(
                id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
                title: "轻启快捷",
                appName: "",
                glyph: "cart.fill",
                tint: "#121211"
            )
        ]
    )
}

struct ShortcutProvider: TimelineProvider {
    func placeholder(in context: Context) -> ShortcutEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (ShortcutEntry) -> Void) {
        completion(context.isPreview ? .placeholder : liveEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ShortcutEntry>) -> Void) {
        let entry = liveEntry()
        // 宿主保存快捷时会主动 reload；半小时兜底刷新一次。
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(1800))))
    }

    private func liveEntry() -> ShortcutEntry {
        ShortcutEntry(date: Date(), shortcuts: OneTapShared.loadSnapshot()?.shortcuts ?? [])
    }
}
