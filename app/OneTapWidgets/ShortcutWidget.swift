import SwiftUI
import WidgetKit

struct ShortcutWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "OneTapShortcutWidget", provider: ShortcutProvider()) { entry in
            ShortcutWidgetView(entry: entry)
        }
        .configurationDisplayName("轻启快捷")
        .description("把已保存的快捷放到桌面，轻点一下交给轻启执行。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct ShortcutWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ShortcutEntry

    var body: some View {
        content
            .containerBackground(for: .widget) {
                Color(hex: 0xF2F0EA)
            }
    }

    private var tileFill: Color {
        Color.white
    }

    private var tileStroke: Color {
        Color.black.opacity(0.07)
    }

    @ViewBuilder
    private var content: some View {
        if entry.shortcuts.isEmpty {
            emptyState
        } else if family == .systemMedium {
            grid(columns: 2, rows: 3, limit: 6, hPadding: 4, vPadding: 4, spacing: 6)
        } else if family == .systemLarge {
            grid(columns: 2, rows: 6, limit: 12, hPadding: 4, vPadding: 4, spacing: 10)
        } else if let hero = entry.hero {
            small(hero: hero)
        } else {
            emptyState
        }
    }

    private func small(hero: WidgetShortcut) -> some View {
        Link(destination: hero.runURL) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    GlyphBadge(symbol: hero.glyph, tint: Color(hexString: hero.tint), size: 26, fillOpacity: 0.16)
                    Spacer()
                    Text("轻启")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.muted)
                }

                Spacer(minLength: 6)

                Text(hero.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x141413))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.leading)

                if !hero.appName.isEmpty {
                    Text(hero.appName)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                        .padding(.top, 3)
                }

                Spacer(minLength: 6)

                HStack {
                    Text("轻点打开")
                        .font(.system(size: 9.5))
                        .foregroundStyle(Theme.muted)
                    Spacer()
                    Image(systemName: "arrow.up.right.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    /// 中号 2×3（6 格，单格约 162×46）、大号 2×6（12 格，单格约 160×49.3）。
    /// 超出上限的条目不再显示，第一个空位放「添加」。
    private func grid(columns: Int, rows: Int, limit: Int, hPadding: CGFloat, vPadding: CGFloat, spacing: CGFloat) -> some View {
        let items = Array(entry.shortcuts.prefix(limit))
        return VStack(spacing: spacing) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<columns, id: \.self) { column in
                        slot(items, at: row * columns + column)
                    }
                }
            }
        }
        .padding(.horizontal, hPadding)
        .padding(.vertical, vPadding)
    }

    @ViewBuilder
    private func slot(_ items: [WidgetShortcut], at index: Int) -> some View {
        if items.indices.contains(index) {
            tile(items[index])
        } else if index == items.count {
            moreTile
        } else {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func tile(_ item: WidgetShortcut) -> some View {
        Link(destination: item.runURL) {
            HStack(spacing: 8) {
                GlyphBadge(symbol: item.glyph, tint: Color(hexString: item.tint), size: 20, fillOpacity: 0.16)

                Text(item.title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x141413))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tileFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(tileStroke, lineWidth: 1)
            )
        }
    }

    private var moreTile: some View {
        Link(destination: OneTapShared.homeURL) {
            HStack(spacing: 5) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                Text("添加")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tileFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(tileStroke, lineWidth: 1)
            )
        }
    }

    private var emptyState: some View {
        Link(destination: OneTapShared.homeURL) {
            VStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.accent)
                Text("还没有快捷")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("打开轻启添加")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
