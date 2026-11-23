import SwiftUI

@MainActor
struct RootView: View {
    @EnvironmentObject private var store: ShortcutStore
    @EnvironmentObject private var catalog: CatalogStore
    @EnvironmentObject private var runner: ShortcutRunner
    @EnvironmentObject private var toast: ToastCenter
    @EnvironmentObject private var runLog: RunLogStore
    @EnvironmentObject private var library: LibraryCoordinator
    @Environment(\.scenePhase) private var scenePhase

    @State private var showComposer = false
    @State private var showAddShortcut = false
    @State private var showShortcutList = false
    @State private var showSettings = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.bg.ignoresSafeArea()

            HomeView(
                onRun: run(_:),
                onCompose: { showComposer = true },
                onAddShortcut: { showAddShortcut = true },
                onManageShortcuts: { showShortcutList = true },
                onSettings: { showSettings = true }
            )

            if let session = runner.session {
                Color(hex: 0x121211)
                    .opacity(0.34)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        if session.phase != .running { runner.dismiss() }
                    }

                RunSheetView(session: session)
                    .transition(.move(edge: .bottom))
            }

            UndoBar(bottomPadding: 104)

            ToastBar(bottomPadding: 104)
        }
        .animation(Theme.sheetAnimation, value: runner.session?.id)
        .onChange(of: scenePhase) { _, newPhase in
            runner.handleScenePhase(newPhase)
        }
        .onChange(of: runner.session?.phase) { _, newPhase in
            guard let session = runner.session else { return }
            if newPhase == .success {
                runLog.mark(
                    appID: session.appID,
                    actionID: session.actionID,
                    result: .reachable,
                    via: session.openVia?.runVia
                )
            } else if newPhase == .failure {
                runLog.mark(
                    appID: session.appID,
                    actionID: session.actionID,
                    result: .unreachable,
                    via: session.openVia?.runVia
                )
            }
        }
        .onOpenURL { url in
            handle(url)
        }
        .fullScreenCover(isPresented: $showComposer) {
            CatalogManagerView()
        }
        .sheet(isPresented: $showAddShortcut) {
            AddShortcutView()
        }
        .sheet(isPresented: $showShortcutList) {
            ShortcutListView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .task {
            WidgetBridge.publish(store: store, catalog: catalog)
        }
        .onChange(of: store.shortcuts) { _, _ in
            WidgetBridge.publish(store: store, catalog: catalog)
        }
        .onChange(of: catalog.apps) { _, _ in
            WidgetBridge.publish(store: store, catalog: catalog)
        }
    }

    private func run(_ shortcut: Shortcut) {
        guard
            let app = catalog.app(id: shortcut.appID),
            let action = catalog.action(appID: shortcut.appID, actionID: shortcut.actionID)
        else {
            toast.show("这条快捷指向的能力已删除，请重新编排")
            return
        }
        let context = RunContext(
            shortcutID: shortcut.id,
            title: shortcut.title,
            app: app,
            action: action
        )
        runner.start(context: context)
    }

    /// onetap://run/<uuid> 给小组件、控制中心预留的统一入口；
    /// onetap://run?app=qqmusic&action=daily 方便直接预览某条能力。
    private func handle(_ url: URL) {
        guard url.scheme == "onetap" else { return }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        if let queryItems = components?.queryItems,
           let appID = queryItems.first(where: { $0.name == "app" })?.value,
           let actionID = queryItems.first(where: { $0.name == "action" })?.value,
           let app = catalog.app(id: appID),
           let action = app.actions.first(where: { $0.id == actionID }) {
            runner.start(context: RunContext(shortcutID: nil, title: action.title, app: app, action: action))
            return
        }

        let identifier = url.pathComponents.dropFirst().joined(separator: "/")
        if let uuid = UUID(uuidString: identifier),
           let shortcut = store.shortcuts.first(where: { $0.id == uuid }) {
            run(shortcut)
            return
        }
    }
}

/// 轻提示外观。RootView 和 sheet 各自挂一份，保证提示出现在当前可见层级。
struct ToastBar: View {
    @EnvironmentObject private var toast: ToastCenter
    var bottomPadding: CGFloat

    var body: some View {
        Group {
            if let message = toast.message {
                Text(message)
                    .font(Theme.textFont(Theme.captionSize, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Theme.ink.opacity(0.92), in: Capsule())
                    .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
                    .padding(.bottom, bottomPadding)
                    .transition(.opacity.combined(with: .offset(y: 12)))
                    .allowsHitTesting(false)
            }
        }
    }
}

/// 删除后的可点击撤销条。页面和全屏流程都要能显示。
struct UndoBar: View {
    @EnvironmentObject private var library: LibraryCoordinator
    var bottomPadding: CGFloat

    var body: some View {
        Group {
            if let undo = library.undo {
                HStack(spacing: 12) {
                    Text(undo.message)
                        .font(Theme.textFont(Theme.captionSize, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Button("撤销") {
                        library.undoLastDeletion()
                    }
                    .font(Theme.textFont(Theme.captionSize, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xFF8A5B))
                }
                .padding(.horizontal, 16)
                .frame(height: 46)
                .background(Theme.ink.opacity(0.94), in: Capsule())
                .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
                .padding(.horizontal, 16)
                .padding(.bottom, bottomPadding)
                .transition(.opacity.combined(with: .offset(y: 12)))
            }
        }
    }
}
