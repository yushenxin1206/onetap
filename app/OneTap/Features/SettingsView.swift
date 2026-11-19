import SwiftUI

@MainActor
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var catalog: CatalogStore
    @EnvironmentObject private var store: ShortcutStore

    var body: some View {
        VStack(spacing: 0) {
            OneTapTopBar(title: "关于", onClose: { dismiss() })

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(store.shortcuts.count) 条快捷 · 全部数据留在本机")
                        .font(Theme.textFont(Theme.captionSize))
                        .foregroundStyle(Theme.muted)
                        .padding(.top, 4)

                    card(title: "数据统计") {
                        infoRow("App", "\(catalog.apps.count) 个")
                        divider
                        infoRow("动作", "\(catalog.actionCount) 条")
                        divider
                        infoRow("快捷", "\(store.shortcuts.count) 条")

                        Text("内置清单只在首次安装时铺底，之后这份目录就是唯一事实：新加、修改、删除都直接生效。")
                            .font(Theme.textFont(11))
                            .foregroundStyle(Theme.muted)
                            .lineSpacing(2)
                            .padding(.top, 10)
                    }

                    card(title: "系统入口") {
                        entryRow(
                            icon: "square.grid.2x2",
                            title: "主屏小组件",
                            subtitle: "小号、中号，展示首页快捷",
                            badge: "已支持"
                        )
                        divider
                        entryRow(
                            icon: "lock",
                            title: "锁屏小组件",
                            subtitle: "圆形、矩形，锁屏直接运行",
                            badge: "已支持"
                        )
                        divider
                        entryRow(
                            icon: "switch.2",
                            title: "控制中心控件",
                            subtitle: "按一下运行首页第一条快捷",
                            badge: controlBadge
                        )
                        Text("桌面长按 → 编辑 → 添加小组件，搜索「轻启」；锁屏同样在编辑状态添加；控制中心在 iOS 18+ 自定义添加。\n扩展只把 onetap://run/<id> 交回轻启，最终跳转由宿主执行。")
                            .font(Theme.textFont(11))
                            .foregroundStyle(Theme.muted)
                            .lineSpacing(3)
                            .padding(.top, 12)
                    }

                    card(title: "边界说明") {
                        Text("轻启只用公开 API：openURL、Universal Link、快捷指令桥。\n不模拟点击、不读取对方状态、不调用私有 API。\n「成功」只代表系统接受了打开请求、轻启退到了后台，不代表对方真的播放或完成了动作。")
                            .font(Theme.textFont(12))
                            .foregroundStyle(Theme.ink2)
                            .lineSpacing(4)
                    }

                    Text("轻启 OneTap · v\(appVersion) · iOS 17+")
                        .font(Theme.monoFont(10))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 28)
                        .padding(.bottom, 20)
                }
                .padding(.horizontal, 22)
            }
        }
        .background(Theme.bg)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.bg)
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.lineSoft)
            .frame(height: 1)
            .padding(.vertical, 8)
    }

    private func card<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(Theme.monoFont(10.5))
                .kerning(1.2)
                .foregroundStyle(Theme.muted)
                .padding(.bottom, 8)
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface(radius: Theme.radiusMedium)
        }
        .padding(.top, 22)
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(Theme.textFont(12.5))
                .foregroundStyle(Theme.muted)
            Spacer()
            Text(value)
                .font(Theme.textFont(12.5, weight: .medium))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var controlBadge: String {
        if #available(iOS 18.0, *) { return "已支持" }
        return "需 iOS 18"
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private func entryRow(icon: String, title: String, subtitle: String, badge: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.ink2)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.textFont(12.5, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(Theme.textFont(10.5))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Text(badge)
                .font(Theme.textFont(9.5))
                .foregroundStyle(badge == "已支持" ? Theme.green : Theme.muted)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    badge == "已支持" ? Theme.greenSoft : Theme.ink.opacity(0.05),
                    in: RoundedRectangle(cornerRadius: 5)
                )
        }
    }
}
