import SwiftUI

/// 快捷层：管理首页引用，不涉及动作池本身。
@MainActor
struct ShortcutListView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: ShortcutStore
    @EnvironmentObject private var catalog: CatalogStore
    @EnvironmentObject private var library: LibraryCoordinator
    @EnvironmentObject private var toast: ToastCenter

    @State private var renaming: Shortcut?
    @State private var editMode: EditMode = .inactive

    var body: some View {
        VStack(spacing: 0) {
            OneTapTopBar(
                title: "我的快捷",
                onClose: { dismiss() },
                actionIcon: editMode == .active ? "checkmark" : "pencil",
                actionLabel: editMode == .active ? "完成" : "编辑",
                onAction: {
                    withAnimation(Theme.sheetAnimation) {
                        editMode = editMode == .active ? .inactive : .active
                    }
                }
            )

            ZStack {
                Theme.bg.ignoresSafeArea()

                if store.shortcuts.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
        }
        .background(Theme.bg)
        .sheet(item: $renaming) { shortcut in
            RenameShortcutView(shortcut: shortcut)
                .environmentObject(store)
        }
        .overlay(alignment: .bottom) {
            UndoBar(bottomPadding: 20)
        }
    }

    private var list: some View {
        List {
            Section {
                ForEach(Array(store.shortcuts.enumerated()), id: \.element.id) { index, shortcut in
                    row(shortcut, index: index)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 5, leading: 22, bottom: 5, trailing: 22))
                }
                .onMove { source, destination in
                    store.move(from: source, to: destination)
                }
                .onDelete { offsets in
                    delete(offsets)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, $editMode)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 22))
                .foregroundStyle(Theme.accent)
            Text("还没有快捷")
                .font(Theme.textFont(14, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("从动作池挑一条动作加到首页。")
                .font(Theme.textFont(12))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func row(_ shortcut: Shortcut, index: Int) -> some View {
        let app = catalog.app(id: shortcut.appID)
        let action = catalog.action(appID: shortcut.appID, actionID: shortcut.actionID)

        return HStack(spacing: 12) {
            GlyphBadge(
                symbol: app?.glyph ?? "questionmark",
                tint: Color(hexString: app?.tint ?? "#121211"),
                size: 34
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(shortcut.title)
                    .font(Theme.textFont(14, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(subtitle(app: app, action: action))
                        .font(Theme.textFont(10.5))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)

                    if index == 0 {
                        Text("首页主快捷")
                            .font(Theme.textFont(9))
                            .foregroundStyle(Color(hex: 0x8F3612))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                Theme.accentSoft,
                                in: RoundedRectangle(cornerRadius: 4)
                            )
                            .fixedSize()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                guard editMode != .active else { return }
                renaming = shortcut
            }

            if editMode != .active {
                Menu {
                    Button {
                        store.promoteToHero(id: shortcut.id)
                    } label: {
                        Label("设为首页主快捷", systemImage: "pin")
                    }
                    .disabled(index == 0)

                    Button {
                        renaming = shortcut
                    } label: {
                        Label("重命名", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        delete(shortcut)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                        .frame(width: 34, height: 40)
                        .contentShape(Rectangle())
                }
            }
        }
        .padding(13)
        .cardSurface(radius: Theme.radiusMedium)
    }

    private func subtitle(app: CapabilityApp?, action: CapabilityAction?) -> String {
        guard let app, let action else { return "指向的动作已删除" }
        return "\(app.name) · \(action.title) · \(action.capability.label)"
    }

    private func delete(_ offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            let shortcut = store.shortcuts[index]
            delete(shortcut)
        }
    }

    private func delete(_ shortcut: Shortcut) {
        if !library.deleteShortcut(shortcut) {
            toast.show("删除没有完成，请再试一次")
        }
    }
}

/// 改名时保留未保存退出的居中确认。
@MainActor
private struct RenameShortcutView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: ShortcutStore

    let shortcut: Shortcut

    @State private var name: String
    @State private var showDiscard = false

    init(shortcut: Shortcut) {
        self.shortcut = shortcut
        _name = State(initialValue: shortcut.title)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isDirty: Bool {
        trimmedName != shortcut.title
    }

    var body: some View {
        VStack(spacing: 0) {
            OneTapTopBar(
                title: "重命名快捷",
                onClose: {
                    if isDirty { showDiscard = true } else { dismiss() }
                },
                actionIcon: "checkmark",
                actionLabel: "保存",
                isActionEnabled: !trimmedName.isEmpty,
                onAction: {
                    store.rename(id: shortcut.id, title: trimmedName)
                    dismiss()
                }
            )

            VStack(alignment: .leading, spacing: 0) {
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

                Text("只改首页显示的名字，不动动作本身。")
                    .font(Theme.textFont(11))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 10)

                Spacer()
            }
            .padding(22)
        }
        .background(Theme.bg)
        .interactiveDismissDisabled(isDirty)
        .alert("放弃这次修改？", isPresented: $showDiscard) {
            Button("放弃修改", role: .destructive) { dismiss() }
            Button("继续编辑", role: .cancel) {}
        } message: {
            Text("还没保存的名字会丢失。")
        }
        .presentationDetents([.height(220)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.bg)
    }
}
