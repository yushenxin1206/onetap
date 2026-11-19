import SwiftUI
import UIKit

@MainActor
struct HomeView: View {
    @EnvironmentObject private var store: ShortcutStore
    @EnvironmentObject private var catalog: CatalogStore
    @EnvironmentObject private var runLog: RunLogStore

    var onRun: (Shortcut) -> Void
    var onCompose: () -> Void
    var onAddShortcut: () -> Void
    var onManageShortcuts: () -> Void
    var onSettings: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header

                    if let hero = heroContent {
                        HeroCard(
                            shortcut: hero.shortcut,
                            app: hero.app,
                            action: hero.action,
                            lastRun: lastRunText(for: hero.shortcut, action: hero.action),
                            onTap: { onRun(hero.shortcut) }
                        )
                        .padding(.top, 22)
                    }

                    HStack(alignment: .firstTextBaseline) {
                        Text("我的快捷")
                            .font(Theme.textFont(Theme.bodySize, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        Button("编辑", action: onManageShortcuts)
                            .font(Theme.textFont(Theme.captionSize))
                            .foregroundStyle(Theme.muted)
                    }
                    .padding(.top, 24)
                    .padding(.horizontal, 2)
                    .padding(.bottom, 10)

                    tileGrid

                    Color.clear.frame(height: 132)
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
            }

            dock
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text(Self.dateLine)
                    .font(Theme.textFont(Theme.captionSize))
                    .foregroundStyle(Theme.muted)
                    .kerning(0.4)
                Text("今天")
                    .font(Theme.displayFont(Theme.titleSize))
                    .foregroundStyle(Theme.ink)
            }
            Spacer()
            Button(action: onAddShortcut) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
                    .frame(width: 38, height: 38)
                    .background(Theme.paper, in: Circle())
                    .overlay(Circle().strokeBorder(Theme.lineSoft, lineWidth: 1))
                    .shadow(color: Theme.ink.opacity(0.05), radius: 2, y: 1)
            }
            .buttonStyle(PressableStyle(scale: 0.92))
            .padding(.top, 2)
        }
    }

    private var tileGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ],
            spacing: 10
        ) {
            ForEach(store.tiles) { shortcut in
                if
                    let app = catalog.app(id: shortcut.appID),
                    let action = catalog.action(appID: shortcut.appID, actionID: shortcut.actionID)
                {
                    TileCard(shortcut: shortcut, app: app, action: action) {
                        onRun(shortcut)
                    }
                }
            }
        }
    }

    private var dock: some View {
        HStack(spacing: 0) {
            DockButton(symbol: "square.grid.2x2", title: "快捷", isActive: true) {}
            DockButton(symbol: "slider.horizontal.3", title: "编排", isActive: false, action: onCompose)
            DockButton(symbol: "info.circle", title: "关于", isActive: false, action: onSettings)
        }
        .frame(height: 60)
        .background(
            Color.white.opacity(0.82),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Theme.lineSoft, lineWidth: 1)
        )
        .shadow(color: Theme.ink.opacity(0.13), radius: 18, y: 12)
        .padding(.horizontal, 22)
        .padding(.bottom, 4)
    }

    private var heroContent: (shortcut: Shortcut, app: CapabilityApp, action: CapabilityAction)? {
        guard
            let shortcut = store.hero,
            let app = catalog.app(id: shortcut.appID),
            let action = catalog.action(appID: shortcut.appID, actionID: shortcut.actionID)
        else { return nil }
        return (shortcut, app, action)
    }

    private func lastRunText(for shortcut: Shortcut, action: CapabilityAction) -> String {
        guard let record = runLog.record(appID: shortcut.appID, actionID: shortcut.actionID) else {
            return "还没跑过"
        }

        let label: String
        if action.isBridge {
            label = record.result == .reachable ? "上次已交给快捷指令" : "上次没交给快捷指令"
        } else {
            label = record.result == .reachable ? "上次可用" : "上次打不开"
        }

        guard let date = record.lastRunAt else { return label }
        if Date().timeIntervalSince(date) < 60 { return "\(label) · 刚刚" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return "\(label) · \(formatter.localizedString(for: date, relativeTo: Date()))"
    }

    private static let weekdayNames = ["", "星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"]

    private static var dateLine: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M 月 d 日"
        let weekday = Calendar.current.component(.weekday, from: Date())
        let name = weekdayNames.indices.contains(weekday) ? weekdayNames[weekday] : ""
        return "\(formatter.string(from: Date())) · \(name)"
    }
}

private struct HeroCard: View {
    let shortcut: Shortcut
    let app: CapabilityApp
    let action: CapabilityAction
    let lastRun: String
    let onTap: () -> Void

    private var tint: Color { Color(hexString: app.tint) }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: app.glyph)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    Text("\(app.name) · \(action.title)")
                        .font(Theme.textFont(Theme.captionSize))
                        .foregroundStyle(.white.opacity(0.66))
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(lastRun)
                        .font(.system(size: 10.5, weight: .regular))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .overlay(
                            Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1)
                        )
                }

                Text(shortcut.title)
                    .font(Theme.displayFont(Theme.titleSize))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 20)

                HStack(alignment: .bottom) {
                    Text(action.capability.label)
                        .font(Theme.textFont(Theme.captionSize))
                        .foregroundStyle(.white.opacity(0.46))

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.top, 12)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack {
                    LinearGradient(
                        colors: [
                            tint.darkened(0.50),
                            tint.darkened(0.78),
                            Color(hex: 0x0B0B0C)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    RadialGradient(
                        colors: [tint.opacity(0.38), tint.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 170
                    )
                    .frame(width: 280, height: 280)
                    .offset(x: 120, y: -100)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Theme.ink.opacity(0.28), radius: 20, y: 14)
        }
        .buttonStyle(PressableStyle(scale: 0.985))
    }
}

private struct TileCard: View {
    let shortcut: Shortcut
    let app: CapabilityApp
    let action: CapabilityAction
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    GlyphBadge(symbol: app.glyph, tint: Color(hexString: app.tint), size: 30)
                    Spacer()
                    Text("↗")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.ink.opacity(0.22))
                }

                Spacer(minLength: 10)

                Text(shortcut.title)
                    .font(Theme.textFont(Theme.bodySize, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)

                Text("\(app.name) · \(action.capability.label)")
                    .font(Theme.textFont(Theme.captionSize))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                    .padding(.top, 3)
            }
            .padding(13)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
            .cardSurface(radius: Theme.radiusMedium)
        }
        .buttonStyle(PressableStyle())
    }
}

private struct DockButton: View {
    let symbol: String
    let title: String
    let isActive: Bool
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .regular))
                Text(title)
                    .font(.system(size: 9.5))
                    .kerning(0.2)
            }
            .foregroundStyle(isActive ? Theme.ink : Theme.muted)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .top) {
                if isActive {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 3, height: 3)
                        .offset(y: 7)
                }
            }
        }
        .buttonStyle(PressableStyle(scale: 0.94))
    }
}

private extension Color {
    /// 混入黑色，用于把 App tint 压成足够深的 Hero 渐变，保证白字对比度。
    func darkened(_ fraction: Double) -> Color {
        let ui = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return self }
        let factor = CGFloat(1 - fraction)
        return Color(red: Double(r * factor), green: Double(g * factor), blue: Double(b * factor))
    }
}
