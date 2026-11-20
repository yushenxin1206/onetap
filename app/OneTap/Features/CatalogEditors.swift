import SwiftUI

/// 新建 / 编辑 App。目录里所有 App 都走这一个编辑器。
@MainActor
struct AppEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let original: CapabilityApp?
    let onSave: (_ name: String, _ tagline: String, _ glyph: String, _ tint: String) -> Void

    @State private var name: String
    @State private var tagline: String
    @State private var glyph: String
    @State private var tint: String
    @State private var showDiscard = false
    @State private var showSymbolPicker = false

    private let glyphChoices = [
        "link", "arrow.up.right.square", "bolt.fill", "star.fill",
        "cart.fill", "book.closed.fill", "film.fill", "music.note"
    ]
    private let tintChoices = ["#2E6BE6", "#1E9E63", "#F0622D", "#E8502E", "#7A5AF8", "#D9352B", "#121211"]

    init(
        original: CapabilityApp?,
        onSave: @escaping (_ name: String, _ tagline: String, _ glyph: String, _ tint: String) -> Void
    ) {
        self.original = original
        self.onSave = onSave
        _name = State(initialValue: original?.name ?? "")
        _tagline = State(initialValue: original?.tagline ?? "自定义入口")
        _glyph = State(initialValue: original?.glyph ?? "link")
        _tint = State(initialValue: original?.tint ?? "#2E6BE6")
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            OneTapTopBar(
                title: original == nil ? "新建 App" : "编辑 App",
                onClose: {
                    if isDirty { showDiscard = true } else { dismiss() }
                },
                actionIcon: "checkmark",
                actionLabel: "保存",
                isActionEnabled: canSave,
                onAction: save
            )

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    fieldLabel("名称")
                    inputField("比如 公司内网、播客", text: $name)

                    fieldLabel("说明")
                    inputField("可选，显示在 App 名称下方", text: $tagline)

                    fieldLabel("图标")
                    inputField("SF Symbols 名称，比如 link", text: $glyph)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    if !glyphIsEmpty && !SymbolCatalog.isValid(glyph) {
                        Text("系统里没有这个符号，检查拼写或大小写。")
                            .font(Theme.textFont(10.5))
                            .foregroundStyle(Color(hex: 0xC0392B))
                            .padding(.top, 6)
                    } else if !glyphIsEmpty && !SymbolCatalog.shared.contains(glyph) {
                        Text("不在推荐清单里，但系统有这个符号。")
                            .font(Theme.textFont(10.5))
                            .foregroundStyle(Theme.muted)
                            .padding(.top, 6)
                    }

                    glyphRow
                    fieldLabel("配色")
                    tintRow

                    fieldLabel("预览")
                    previewCard

                    Text("App 只是动作的容器；能不能打开由动作里的 URL 决定。")
                        .font(Theme.textFont(11))
                        .foregroundStyle(Theme.muted)
                        .padding(.top, 12)
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
        }
        .background(Theme.bg)
        .interactiveDismissDisabled(isDirty)
        .alert("放弃这次修改？", isPresented: $showDiscard) {
            Button("放弃修改", role: .destructive) { dismiss() }
            Button("继续编辑", role: .cancel) {}
        } message: {
            Text("还没保存的内容会丢失。")
        }
        .sheet(isPresented: $showSymbolPicker) {
            SymbolPickerView(current: glyph) { glyph = $0 }
        }
    }

    private var glyphIsEmpty: Bool {
        glyph.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isDirty: Bool {
        name != (original?.name ?? "")
            || tagline != (original?.tagline ?? "自定义入口")
            || glyph != (original?.glyph ?? "link")
            || tint != (original?.tint ?? "#2E6BE6")
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && SymbolCatalog.isValid(glyph)
    }

    private var glyphRow: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(glyphChoices, id: \.self) { symbol in
                        Button {
                            glyph = symbol
                        } label: {
                            Image(systemName: symbol)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(glyph == symbol ? Color.white : Theme.ink2)
                                .frame(width: 38, height: 38)
                                .background(
                                    glyph == symbol ? Theme.ink : Theme.paper,
                                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .strokeBorder(glyph == symbol ? Color.clear : Theme.lineSoft, lineWidth: 1)
                                )
                        }
                        .buttonStyle(PressableStyle(scale: 0.94))
                    }
                }
            }

            Button {
                showSymbolPicker = true
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 13, weight: .medium))
                    Text("更多")
                        .font(Theme.textFont(7.5))
                }
                .foregroundStyle(Theme.ink2)
                .frame(width: 38, height: 38)
                .background(
                    Theme.paper,
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(Theme.lineSoft, lineWidth: 1)
                )
            }
            .buttonStyle(PressableStyle(scale: 0.94))
            .accessibilityLabel("浏览全部图标")
        }
        .padding(.top, 10)
    }

    private var tintRow: some View {
        HStack(spacing: 10) {
            ForEach(tintChoices, id: \.self) { value in
                Button {
                    tint = value
                } label: {
                    Circle()
                        .fill(Color(hexString: value))
                        .frame(width: 26, height: 26)
                        .overlay(
                            Circle()
                                .strokeBorder(Theme.ink.opacity(tint == value ? 0.55 : 0), lineWidth: 2)
                                .padding(-3)
                        )
                }
                .buttonStyle(PressableStyle(scale: 0.9))
            }
        }
        .padding(.top, 2)
    }

    private var previewCard: some View {
        HStack(spacing: 11) {
            GlyphBadge(symbol: glyph, tint: Color(hexString: tint), size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(trimmedName.isEmpty ? "未命名" : trimmedName)
                    .font(Theme.textFont(14, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Text(tagline.isEmpty ? "自定义入口" : tagline)
                    .font(Theme.textFont(10.5))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(14)
        .cardSurface(radius: Theme.radiusMedium)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.monoFont(10.5))
            .kerning(1.2)
            .foregroundStyle(Theme.muted)
            .padding(.top, 20)
            .padding(.bottom, 8)
    }

    private func inputField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(Theme.textFont(14))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.lineSoft, lineWidth: 1)
            )
    }

    private func save() {
        guard canSave else { return }
        onSave(
            trimmedName,
            tagline.trimmingCharacters(in: .whitespacesAndNewlines),
            glyph.trimmingCharacters(in: .whitespaces),
            tint
        )
        dismiss()
    }
}

/// 新建 / 编辑动作。一条动作只有一条 URL：http(s) 走 Universal Link，其余走 scheme。
@MainActor
struct ActionEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let appID: String
    let appName: String
    let original: CapabilityAction?
    let onSave: (CapabilityAction) -> Void

    enum ActionKind: String, CaseIterable, Identifiable {
        case link
        case shortcut

        var id: String { rawValue }

        var title: String {
            switch self {
            case .link: return "打开链接"
            case .shortcut: return "运行快捷指令"
            }
        }
    }

    @State private var kind: ActionKind
    @State private var title: String
    @State private var url: String
    @State private var shortcutName: String
    @State private var subtitle: String
    @State private var customTitle: Bool
    @State private var showDiscard = false

    init(appID: String, appName: String, original: CapabilityAction?, onSave: @escaping (CapabilityAction) -> Void) {
        self.appID = appID
        self.appName = appName
        self.original = original
        self.onSave = onSave
        _kind = State(initialValue: original?.isBridge == true ? .shortcut : .link)
        _title = State(initialValue: original?.title ?? "")
        _url = State(initialValue: original?.normalizedURL ?? "")
        _shortcutName = State(initialValue: original?.shortcutName ?? "")
        _subtitle = State(initialValue: original?.subtitle ?? "")
        let existingTitle = original?.title ?? ""
        let existingName = original?.shortcutName ?? ""
        _customTitle = State(initialValue: original?.isBridge == true && existingTitle != existingName)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedURL: String {
        url.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var urlIsValid: Bool {
        CapabilityAction.isValid(url: trimmedURL)
    }

    private var trimmedShortcutName: String {
        shortcutName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        switch kind {
        case .link:
            return !trimmedTitle.isEmpty && urlIsValid
        case .shortcut:
            return !trimmedShortcutName.isEmpty
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            OneTapTopBar(
                title: original == nil ? "新建动作" : "编辑动作",
                onClose: {
                    if isDirty { showDiscard = true } else { dismiss() }
                },
                actionIcon: "checkmark",
                actionLabel: "保存",
                isActionEnabled: canSave,
                onAction: save
            )

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(appName)
                        .font(Theme.textFont(12))
                        .foregroundStyle(Theme.muted)
                        .padding(.top, 4)

                    fieldLabel("动作类型")
                    kindChips

                    switch kind {
                    case .link:
                        fieldLabel("动作名称")
                        inputField("比如 打开工作台", text: $title)

                        fieldLabel("地址")
                        inputField("weixin:// 或 https://…", text: $url)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)

                        if !trimmedURL.isEmpty && !urlIsValid {
                            Text("这串地址不完整：网页地址要带域名，App 地址要带 scheme。")
                                .font(Theme.textFont(11))
                                .foregroundStyle(Color(hex: 0xA2400F))
                                .padding(.top, 8)
                                .padding(.horizontal, 2)
                        }

                        Text("只能填一条地址。想只打开 App 首页，就填它的根地址，例如 weixin://。")
                            .font(Theme.textFont(11))
                            .foregroundStyle(Theme.muted)
                            .lineSpacing(2)
                            .padding(.top, 8)
                            .padding(.horizontal, 2)
                    case .shortcut:
                        fieldLabel("动作名称")
                        shortcutTitleEditor

                        fieldLabel("快捷指令名称")
                        inputField("比如 播放每日推荐", text: $shortcutName)

                        Text("先在「快捷指令」里创建同名快捷指令。轻启会调用它，但系统不回报执行结果，只能确认已经交给它。")
                            .font(Theme.textFont(11))
                            .foregroundStyle(Theme.muted)
                            .lineSpacing(2)
                            .padding(.top, 8)
                            .padding(.horizontal, 2)
                    }

                    fieldLabel("备注")
                    inputField("可选，显示在动作下方", text: $subtitle)

                    if let original {
                        Text("上次结果：\(resultLabel(for: original))")
                            .font(Theme.textFont(11))
                            .foregroundStyle(Theme.muted)
                            .padding(.top, 14)
                            .padding(.horizontal, 2)
                    }

                    Text(kind == .shortcut
                         ? "结果页只会说「已交给快捷指令」，不会声称执行成功。"
                         : "轻启只按这条地址去唤起目标，能不能落到页面由对方决定；结果页只说「已打开」。")
                        .font(Theme.textFont(11))
                        .foregroundStyle(Theme.muted)
                        .lineSpacing(2)
                        .padding(.top, 12)
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
        }
        .background(Theme.bg)
        .interactiveDismissDisabled(isDirty)
        .alert("放弃这次修改？", isPresented: $showDiscard) {
            Button("放弃修改", role: .destructive) { dismiss() }
            Button("继续编辑", role: .cancel) {}
        } message: {
            Text("还没保存的内容会丢失。")
        }
    }

    private var isDirty: Bool {
        let initialKind: ActionKind = original?.isBridge == true ? .shortcut : .link
        let initialCustom = original?.isBridge == true
            && (original?.title ?? "") != (original?.shortcutName ?? "")
        let titleChanged: Bool
        switch kind {
        case .link:
            titleChanged = trimmedTitle != (original?.title ?? "")
        case .shortcut:
            titleChanged = customTitle != initialCustom
                || (customTitle && trimmedTitle != (original?.title ?? ""))
        }
        return kind != initialKind
            || titleChanged
            || url != (original?.normalizedURL ?? "")
            || shortcutName != (original?.shortcutName ?? "")
            || subtitle != (original?.subtitle ?? "")
    }

    /// 运行快捷指令：未开自定义时标题跟随快捷指令名；开了但留空也回落。
    private var effectiveTitle: String {
        switch kind {
        case .link:
            return trimmedTitle
        case .shortcut:
            guard customTitle else { return trimmedShortcutName }
            return trimmedTitle.isEmpty ? trimmedShortcutName : trimmedTitle
        }
    }

    private var shortcutTitleEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if !customTitle {
                    Text("默认与快捷指令名相同")
                        .font(Theme.textFont(12))
                        .foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
                Toggle("自定义名称", isOn: $customTitle)
                    .font(Theme.textFont(12))
                    .foregroundStyle(Theme.ink2)
                    .tint(Theme.ink)
                    .fixedSize()
            }

            if customTitle {
                inputField("不填则跟随快捷指令名", text: $title)
            }
        }
        .padding(.top, 2)
    }

    private var kindChips: some View {
        HStack(spacing: 7) {
            ForEach(ActionKind.allCases) { item in
                Button {
                    kind = item
                } label: {
                    Text(item.title)
                        .font(Theme.textFont(11.5))
                        .foregroundStyle(kind == item ? Color.white : Theme.ink2)
                        .padding(.horizontal, 11)
                        .frame(height: 31)
                        .background(
                            kind == item ? Theme.ink : Color.white.opacity(0.72),
                            in: Capsule()
                        )
                        .overlay(
                            Capsule().strokeBorder(
                                kind == item ? Color.clear : Theme.lineSoft,
                                lineWidth: 1
                            )
                        )
                }
                .buttonStyle(PressableStyle(scale: 0.95))
            }
        }
        .padding(.top, 2)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.monoFont(10.5))
            .kerning(1.2)
            .foregroundStyle(Theme.muted)
            .padding(.top, 20)
            .padding(.bottom, 8)
    }

    private func inputField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(Theme.textFont(14))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.lineSoft, lineWidth: 1)
            )
    }

    private func resultLabel(for action: CapabilityAction) -> String {
        guard let record = RunLogStore.shared.record(appID: appID, actionID: action.id) else {
            return "未验证"
        }
        guard action.isBridge else { return record.result.label }
        return record.result == .reachable ? "已交给快捷指令" : "没交给快捷指令"
    }

    private func save() {
        guard canSave else { return }

        var saved = original ?? CapabilityAction(
            id: UUID().uuidString,
            title: trimmedTitle,
            subtitle: nil,
            url: nil,
            shortcutName: nil
        )

        saved.title = effectiveTitle
        saved.subtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil
            : subtitle.trimmingCharacters(in: .whitespacesAndNewlines)

        switch kind {
        case .shortcut:
            saved.url = nil
            saved.shortcutName = trimmedShortcutName
        case .link:
            saved.shortcutName = nil
            saved.url = trimmedURL
        }

        onSave(saved)
        dismiss()
    }
}
