import SwiftUI
import WidgetKit

/// 「轻启」：锁屏上点一下打开宿主 App。
struct LockShortcutWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "OneTapLockWidget", provider: ShortcutProvider()) { _ in
            LockHomeWidgetView()
        }
        .configurationDisplayName("轻启")
        .description("锁屏上放一个入口，轻点打开轻启。")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

/// 「轻启 · 主快捷」：显示并执行首页主快捷。
struct LockHeroShortcutWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "OneTapLockHeroWidget", provider: ShortcutProvider()) { entry in
            LockHeroWidgetView(entry: entry)
        }
        .configurationDisplayName("轻启 · 主快捷")
        .description("锁屏上放一条主快捷，轻点交给轻启执行。")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

/// 打开宿主 App 的锁屏入口，不依赖快捷数据。
struct LockHomeWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 18, weight: .medium))
                        .widgetAccentable()
                }
            case .accessoryInline:
                Text("打开轻启")
            default:
                HStack(spacing: 7) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14, weight: .medium))
                        .widgetAccentable()

                    VStack(alignment: .leading, spacing: 1) {
                        Text("轻启")
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                        Text("轻点打开")
                            .font(.system(size: 10))
                            .opacity(0.75)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
            }
        }
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(OneTapShared.homeURL)
    }
}

/// 主快捷：显示当前 Hero，整块点击交给轻启执行。
struct LockHeroWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ShortcutEntry

    var body: some View {
        Group {
            if let hero = entry.hero {
                switch family {
                case .accessoryCircular:
                    circular(hero: hero)
                case .accessoryInline:
                    Text("打开 \(hero.title)")
                default:
                    rectangular(hero: hero)
                }
            } else {
                switch family {
                case .accessoryCircular:
                    ZStack {
                        AccessoryWidgetBackground()
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 18, weight: .medium))
                            .widgetAccentable()
                    }
                case .accessoryInline:
                    Text("打开轻启")
                default:
                    Text("还没有快捷 · 打开轻启添加")
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                }
            }
        }
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(entry.hero?.runURL ?? OneTapShared.homeURL)
    }

    private func rectangular(hero: WidgetShortcut) -> some View {
        HStack(spacing: 7) {
            Image(systemName: hero.glyph)
                .font(.system(size: 14, weight: .medium))
                .widgetAccentable()

            VStack(alignment: .leading, spacing: 1) {
                Text(hero.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Text(hero.appName.isEmpty ? "轻点打开" : "\(hero.appName) · 轻点打开")
                    .font(.system(size: 10))
                    .opacity(0.75)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }

    private func circular(hero: WidgetShortcut) -> some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: hero.glyph)
                .font(.system(size: 20, weight: .medium))
                .widgetAccentable()
        }
    }
}
