import SwiftUI

/// 图标库：展开浏览内置精选清单，选中即回填。
@MainActor
struct SymbolPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let current: String
    let onPick: (String) -> Void

    @State private var query = ""

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 9), count: 6)

    var body: some View {
        VStack(spacing: 0) {
            OneTapTopBar(title: "选择图标", onClose: { dismiss() })

            ZStack {
                Theme.bg.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    searchField
                        .padding(.horizontal, 22)
                        .padding(.top, 8)

                    ScrollView(.vertical, showsIndicators: false) {
                        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            ForEach(SymbolCatalog.shared.groups) { group in
                                groupSection(group)
                            }
                        } else {
                            resultSection
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 28)
                }
            }
        }
        .background(Theme.bg)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.muted)
            TextField("搜索图标名称，如 play、音乐", text: $query)
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

    private func groupSection(_ group: SymbolGroup) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(group.name)
                .font(Theme.monoFont(10.5))
                .kerning(1.2)
                .foregroundStyle(Theme.muted)
                .padding(.top, 20)
                .padding(.bottom, 8)

            LazyVGrid(columns: columns, spacing: 9) {
                ForEach(group.symbols) { item in
                    cell(item)
                }
            }
        }
    }

    private var resultSection: some View {
        let items = SymbolCatalog.shared.search(query)
        return Group {
            if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.muted)
                    Text("清单里没有匹配的图标")
                        .font(Theme.textFont(13, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("可以直接在输入框填 SF Symbols 名称。")
                        .font(Theme.textFont(11))
                        .foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 48)
            } else {
                LazyVGrid(columns: columns, spacing: 9) {
                    ForEach(items) { item in
                        cell(item)
                    }
                }
                .padding(.top, 16)
            }
        }
    }

    private func cell(_ item: SymbolItem) -> some View {
        let selected = item.name == current
        return Button {
            onPick(item.name)
            dismiss()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: item.name)
                    .font(.system(size: 17, weight: .medium))
                Text(item.label)
                    .font(Theme.textFont(8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(selected ? Color.white : Theme.ink2)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                selected ? Theme.ink : Theme.paper,
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(selected ? Color.clear : Theme.lineSoft, lineWidth: 1)
            )
        }
        .buttonStyle(PressableStyle(scale: 0.94))
        .accessibilityLabel(item.label)
    }
}
