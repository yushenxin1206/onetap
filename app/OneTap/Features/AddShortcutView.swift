import SwiftUI

/// 快捷层新增入口：从动作池里挑一条已有动作，命名后追加到首页末尾。
@MainActor
struct AddShortcutView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: ShortcutStore
    @EnvironmentObject private var catalog: CatalogStore
    @EnvironmentObject private var toast: ToastCenter

    @State private var query = ""
    @State private var draft: Draft?

    /// true：添加后留在本页继续添加（从「我的快捷」进来）；
    /// false：添加后关闭本页（首页「＋」原有行为）。
    private let staysOpenAfterAdd: Bool

    init(staysOpenAfterAdd: Bool = false) {
        self.staysOpenAfterAdd = staysOpenAfterAdd
    }

    fileprivate struct Draft: Identifiable {
        let id = UUID()
        let app: CapabilityApp
        let action: CapabilityAction
    }

    var body: some View {
        VStack(spacing: 0) {
            OneTapTopBar(title: "添加快捷", onClose: { dismiss() })

            ZStack {
                Theme.bg.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    searchField
                        .padding(.horizontal, 22)
                        .padding(.top, 8)

                    if filteredApps.isEmpty {
                        emptyState
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(filteredApps) { app in
                                    section(app)
                                }
                            }
                            .padding(.horizontal, 22)
                            .padding(.bottom, 32)
                        }
                    }
                }
            }
        }
        .background(Theme.bg)
        .sheet(item: $draft) { draft in
            AddShortcutNamingView(draft: draft) { title in
                store.add(
                    Shortcut(
                        id: UUID(),
                        title: title,
                        appID: draft.app.id,
                        actionID: draft.action.id
                    )
                )
                toast.show("已添加「\(title)」到末尾")
                if !staysOpenAfterAdd { dismiss() }
            }
        }
    }

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

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 22))
                .foregroundStyle(Theme.muted)
            Text(query.isEmpty ? "动作池还是空的" : "没有匹配的动作")
                .font(Theme.textFont(14, weight: .semibold))
                .foregroundStyle(Theme.ink)
            if query.isEmpty {
                Text("先去「编排」里添加 App 和动作。")
                    .font(Theme.textFont(12))
                    .foregroundStyle(Theme.muted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func section(_ app: CapabilityApp) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                GlyphBadge(symbol: app.glyph, tint: Color(hexString: app.tint), size: 24)
                Text(app.name)
                    .font(Theme.monoFont(10.5))
                    .kerning(1.2)
                    .foregroundStyle(Theme.muted)
            }
            .padding(.top, 20)
            .padding(.bottom, 8)

            VStack(spacing: 0) {
                ForEach(Array(app.actions.enumerated()), id: \.element.id) { index, action in
                    Button {
                        draft = Draft(app: app, action: action)
                    } label: {
                        actionRow(action)
                    }
                    .buttonStyle(PressableStyle(scale: 0.995))

                    if index < app.actions.count - 1 {
                        Rectangle()
                            .fill(Theme.lineSoft)
                            .frame(height: 1)
                            .padding(.leading, 14)
                    }
                }
            }
            .cardSurface(radius: Theme.radiusMedium)
        }
    }

    private func actionRow(_ action: CapabilityAction) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(action.title)
                    .font(Theme.textFont(14, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Text(action.capability.label)
                    .font(Theme.textFont(10.5))
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 6)
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.ink2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var filteredApps: [CapabilityApp] {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return catalog.apps.compactMap { app in
            let actions = app.actions.filter { action in
                guard !keyword.isEmpty else { return true }
                return app.name.localizedCaseInsensitiveContains(keyword)
                    || action.title.localizedCaseInsensitiveContains(keyword)
            }
            guard !actions.isEmpty else { return nil }
            var copy = app
            copy.actions = actions
            return copy
        }
    }
}

/// 给这条快捷起名；未保存退出沿用居中确认。
@MainActor
private struct AddShortcutNamingView: View {
    @Environment(\.dismiss) private var dismiss

    let draft: AddShortcutView.Draft
    let onAdd: (String) -> Void

    @State private var name: String
    @State private var showDiscard = false

    init(draft: AddShortcutView.Draft, onAdd: @escaping (String) -> Void) {
        self.draft = draft
        self.onAdd = onAdd
        _name = State(initialValue: draft.action.title)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isDirty: Bool {
        trimmedName != draft.action.title
    }

    var body: some View {
        VStack(spacing: 0) {
            OneTapTopBar(
                title: "加到首页",
                onClose: {
                    if isDirty { showDiscard = true } else { dismiss() }
                },
                actionIcon: "checkmark",
                actionLabel: "保存",
                isActionEnabled: !trimmedName.isEmpty,
                onAction: {
                    onAdd(trimmedName)
                    dismiss()
                }
            )

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    GlyphBadge(
                        symbol: draft.app.glyph,
                        tint: Color(hexString: draft.app.tint),
                        size: 30
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(draft.action.title)
                            .font(Theme.textFont(13, weight: .medium))
                            .foregroundStyle(Theme.ink)
                        Text(draft.app.name)
                            .font(Theme.textFont(10.5))
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer()
                }

                TextField("快捷名称", text: $name)
                    .font(Theme.textFont(14))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .background(Theme.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Theme.lineSoft, lineWidth: 1)
                    )
                    .padding(.top, 16)

                Text("同一动作可以加多次，名字也能相同；之后可在「我的快捷」里改名或排序。")
                    .font(Theme.textFont(11))
                    .foregroundStyle(Theme.muted)
                    .lineSpacing(2)
                    .padding(.top, 10)

                Spacer()
            }
            .padding(22)
        }
        .background(Theme.bg)
        .interactiveDismissDisabled(isDirty)
        .alert("放弃这条快捷？", isPresented: $showDiscard) {
            Button("放弃修改", role: .destructive) { dismiss() }
            Button("继续编辑", role: .cancel) {}
        } message: {
            Text("已经选的动作和名字都会丢掉。")
        }
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.bg)
    }
}
