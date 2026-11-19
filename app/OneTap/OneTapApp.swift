import SwiftUI
import WidgetKit

@main
struct OneTapApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = ShortcutStore.shared
    @StateObject private var catalog = CatalogStore.shared
    @StateObject private var runner = ShortcutRunner()
    @StateObject private var toast = ToastCenter()
    @StateObject private var runLog = RunLogStore.shared
    @StateObject private var library = LibraryCoordinator.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(catalog)
                .environmentObject(runner)
                .environmentObject(toast)
                .environmentObject(runLog)
                .environmentObject(library)
                .preferredColorScheme(.light)
                .tint(Theme.accent)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }
        }
    }
}
