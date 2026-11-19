import SwiftUI

@MainActor
struct AppPickerStep: View {
    @EnvironmentObject private var catalog: CatalogStore
    @EnvironmentObject private var store: ShortcutStore
    @EnvironmentObject private var toast: ToastCenter
    @EnvironmentObject private var library: LibraryCoordinator

    let onOpenApp: (CapabilityApp) -> Void

    @State private var query = ""
    @State private var addingApp = false
    @State private var editingApp: CapabilityApp?
    @State private var pendingDelete: CapabilityApp?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("能力目录")
                .font(Theme.displayFont(Theme.headlineSize))
                .foregroundStyle(Theme.ink)
                .padding(.top, 2)
            Text("这里管理 App 和动作；首页快捷从这些动作里挑。")
                .font(Theme.textFont(12))
                .foregroundStyle(Theme.muted)
                .padding(.top, 6)

            searchField
                .padding(.top, 16)

            if visibleApps.isEmpty {
                Text(query.isEmpty ? "目录是空的，先新建一个 App" : "没有匹配的 App")
                    .font(Theme.textFont(13))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 36)
            } else {
                sectionLabel("全部 APP")
            }

            appCard

            Text("动作里的「未验证」表示还没真跑过；跑过一次后按真实结果记「可用」或「打不开」。")
                .font(Theme.textFont(11))
                .foregroundStyle(Theme.muted)
                .lineSpacing(2)
                .padding(.top, 16)
                .padding(.horizontal, 2)
        }
        .sheet(isPresented: $addingApp) {
            AppEditorView(original: nil) { name, tagline, glyph, tint in
                let app = catalog.addApp(name: name, tagline: tagline, glyph: glyph, tint: tint)
                toast.show("已添加「\(app.name)」，接着给它加动作")
                onOpenApp(app)
            }
        }
        .sheet(item: $editingApp) { app in
            AppEditorView(original: app) { name, tagline, glyph, tint in
                catalog.updateApp(id: app.id, name: name, tagline: tagline, glyph: glyph, tint: tint)
                toast.show("已更新「\(name)」")
            }
        }
        .alert(
            pendingDelete.map { "删除「\($0.name)」会同时删除 \(library.shortcutCount(appID: $0.id)) 条快捷" } ?? "",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            )
        ) {
            Button("删除", role: .destructive) {
                if let app = pendingDelete { delete(app) }
                pendingDelete = nil
            }
            Button("取消", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("目录、快捷和运行记录会一起删除，桌面小组件也会同步更新。")
        }
    }

    // MARK: - 搜索

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.muted)
            TextField("搜索 App 或动作", text: $query)
                .font(Theme.textFont(14))
                .foregroundStyle(Theme.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.muted.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(
            Theme.ink.opacity(0.055),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.monoFont(10.5))
            .kerning(1.2)
            .foregroundStyle(Theme.muted)
            .padding(.top, 20)
            .padding(.bottom, 8)
            .padding(.horizontal, 2)
    }

    // MARK: - 列表

    private var appCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(visibleApps.enumerated()), id: \.element.id) { index, app in
                HStack(spacing: 0) {
                    Button {
                        onOpenApp(app)
                    } label: {
                        appRowLabel(app)
                    }
                    .buttonStyle(PressableStyle(scale: 0.995))

                    Menu {
                        Button("编辑 App") {
                            editingApp = app
                        }
                        Button("删除 App", role: .destructive) {
                            if library.shortcutCount(appID: app.id) > 0 {
                                pendingDelete = app
                            } else {
                                delete(app)
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.muted)
                            .frame(width: 40, height: 44)
                            .contentShape(Rectangle())
                    }
                }
                .padding(.trailing, 6)

                if index < visibleApps.count - 1 {
                    Rectangle()
                        .fill(Theme.lineSoft)
                        .frame(height: 1)
                        .padding(.leading, 62)
                }
            }

            if !visibleApps.isEmpty {
                Rectangle()
                    .fill(Theme.lineSoft)
                    .frame(height: 1)
                    .padding(.leading, 62)
            }

            Button {
                addingApp = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.ink2)
                        .frame(width: 36, height: 36)
                        .background(
                            Theme.ink.opacity(0.05),
                            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                        )
                    Text("新建 App")
                        .font(Theme.textFont(Theme.bodySize, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle(scale: 0.995))
        }
        .cardSurface(radius: Theme.radiusMedium)
    }

    private func appRowLabel(_ app: CapabilityApp) -> some View {
        HStack(spacing: 12) {
            GlyphBadge(symbol: app.glyph, tint: Color(hexString: app.tint), size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(Theme.textFont(14, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Text(app.tagline)
                    .font(Theme.textFont(10.5))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.ink.opacity(0.3))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    // MARK: - 数据

    private func delete(_ app: CapabilityApp) {
        if !library.deleteApp(app) {
            toast.show("删除没有完成，请再试一次")
        }
    }

    private var keyword: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var visibleApps: [CapabilityApp] {
        guard !keyword.isEmpty else { return catalog.apps }
        return catalog.apps.filter {
            $0.name.localizedCaseInsensitiveContains(keyword)
                || $0.tagline.localizedCaseInsensitiveContains(keyword)
                || $0.actions.contains { $0.title.localizedCaseInsensitiveContains(keyword) }
        }
    }
}

@MainActor
struct ActionPickerStep: View {
    @EnvironmentObject private var catalog: CatalogStore
    @EnvironmentObject private var store: ShortcutStore
    @EnvironmentObject private var toast: ToastCenter
    @EnvironmentObject private var runLog: RunLogStore
    @EnvironmentObject private var library: LibraryCoordinator

    let app: CapabilityApp

    @State private var addingAction = false
    @State private var editingAction: CapabilityAction?
    @State private var pendingDelete: CapabilityAction?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("动作")
                .font(Theme.displayFont(Theme.headlineSize))
                .foregroundStyle(Theme.ink)
                .padding(.top, 2)
            Text("点动作可编辑；这一页就是动作池。")
                .font(Theme.textFont(12))
                .foregroundStyle(Theme.muted)
                .padding(.top, 6)

            HStack(spacing: 11) {
                GlyphBadge(symbol: app.glyph, tint: Color(hexString: app.tint), size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(Theme.textFont(14, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    Text(app.tagline)
                        .font(Theme.textFont(10.5))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(14)
            .cardSurface(radius: Theme.radiusMedium)
            .padding(.top, 16)

            Text("动作")
                .font(Theme.monoFont(10.5))
                .kerning(1.2)
                .foregroundStyle(Theme.muted)
                .padding(.top, 22)
                .padding(.bottom, 8)
                .padding(.horizontal, 2)

            VStack(spacing: 0) {
                ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                    HStack(spacing: 0) {
                        Button {
                            editingAction = action
                        } label: {
                            actionRowLabel(action)
                        }
                        .buttonStyle(PressableStyle(scale: 0.995))

                        Menu {
                            Button("编辑动作") {
                                editingAction = action
                            }
                            Button("删除动作", role: .destructive) {
                                if library.shortcutCount(appID: app.id, actionID: action.id) > 0 {
                                    pendingDelete = action
                                } else {
                                    delete(action)
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.muted)
                                .frame(width: 40, height: 44)
                                .contentShape(Rectangle())
                        }
                    }
                    .padding(.trailing, 6)

                    if index < actions.count - 1 {
                        Rectangle()
                            .fill(Theme.lineSoft)
                            .frame(height: 1)
                            .padding(.leading, 14)
                    }
                }

                if !actions.isEmpty {
                    Rectangle()
                        .fill(Theme.lineSoft)
                        .frame(height: 1)
                        .padding(.leading, 14)
                }

                Button {
                    addingAction = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.ink2)
                        Text(actions.isEmpty ? "添加第一个动作" : "添加动作")
                            .font(Theme.textFont(14, weight: .medium))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle(scale: 0.995))
            }
            .cardSurface(radius: Theme.radiusMedium)

            Text("未验证：还没真跑过；可用：最近一次成功离开轻启；打不开：最近一次系统没接受。轻启不承诺页面里的后续操作。")
                .font(Theme.textFont(11))
                .foregroundStyle(Theme.muted)
                .lineSpacing(2)
                .padding(.top, 14)
                .padding(.horizontal, 2)
        }
        .sheet(isPresented: $addingAction) {
            ActionEditorView(appID: app.id, appName: app.name, original: nil) { saved in
                catalog.addAction(appID: app.id, action: saved)
                toast.show("已添加动作「\(saved.title)」")
            }
        }
        .sheet(item: $editingAction) { action in
            ActionEditorView(appID: app.id, appName: app.name, original: action) { saved in
                catalog.updateAction(appID: app.id, action: saved)
                toast.show("已更新动作「\(saved.title)」")
            }
        }
        .alert(
            pendingDelete.map {
                "删除「\($0.title)」会同时删除 \(library.shortcutCount(appID: app.id, actionID: $0.id)) 条快捷"
            } ?? "",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            )
        ) {
            Button("删除", role: .destructive) {
                if let action = pendingDelete { delete(action) }
                pendingDelete = nil
            }
            Button("取消", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("动作、引用它的快捷和运行记录会一起删除，桌面小组件也会同步更新。")
        }
    }

    /// 始终读目录里的最新动作，编辑后立刻反映。
    private var actions: [CapabilityAction] {
        catalog.app(id: app.id)?.actions ?? app.actions
    }

    private func actionRowLabel(_ action: CapabilityAction) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(action.title)
                    .font(Theme.textFont(14, weight: .medium))
                    .foregroundStyle(Theme.ink)
                if let subtitle = action.subtitle {
                    Text(subtitle)
                        .font(Theme.textFont(10.5))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 6)

            HStack(spacing: 5) {
                CapabilityTag(capability: action.capability)
                runStatusTag(for: action)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.ink.opacity(0.3))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func runStatusTag(for action: CapabilityAction) -> some View {
        let record = runLog.record(appID: app.id, actionID: action.id)
        let isBridge = action.isBridge
        let result = record?.result

        let label: String
        switch result {
        case .none:
            label = "未验证"
        case .reachable:
            label = isBridge ? "已交给快捷指令" : "可用"
        case .unreachable:
            label = isBridge ? "没交给快捷指令" : "打不开"
        }

        let foreground: Color
        let background: Color
        switch result {
        case .none:
            foreground = Color(hex: 0x6E6D66)
            background = Theme.ink.opacity(0.05)
        case .reachable:
            foreground = Color(hex: 0x177A4C)
            background = Theme.greenSoft
        case .unreachable:
            foreground = Color(hex: 0xA2400F)
            background = Theme.accentSoft
        }
        return Text(label)
            .font(Theme.textFont(9.5, weight: .medium))
            .foregroundStyle(foreground)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(background, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    private func delete(_ action: CapabilityAction) {
        if !library.deleteAction(appID: app.id, action: action) {
            toast.show("删除没有完成，请再试一次")
        }
    }
}
