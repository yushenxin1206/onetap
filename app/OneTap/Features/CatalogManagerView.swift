import SwiftUI

/// 动作池管理入口：App 列表 → 动作列表，只负责目录的增删改。
@MainActor
struct CatalogManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var catalog: CatalogStore

    @State private var path: [String] = []

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                OneTapTopBar(title: "编排", onClose: { dismiss() })

                ScrollView(.vertical, showsIndicators: false) {
                    AppPickerStep { app in
                        path.append(app.id)
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 32)
                }
            }
            .background(Theme.bg)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { appID in
                if let app = catalog.app(id: appID) {
                    ScrollView(.vertical, showsIndicators: false) {
                        ActionPickerStep(app: app)
                            .padding(.horizontal, 22)
                            .padding(.bottom, 32)
                    }
                    .background(Theme.bg)
                    .navigationTitle(app.name)
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .overlay(alignment: .bottom) {
            UndoBar(bottomPadding: 20)
        }
    }
}
