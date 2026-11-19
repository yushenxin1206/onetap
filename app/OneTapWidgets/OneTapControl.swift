import AppIntents
import SwiftUI
import WidgetKit

@available(iOS 18.0, *)
struct OneTapControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "app.onetap.launcher.control.hero") {
            ControlWidgetButton(action: OpenURLIntent(targetURL)) {
                Label(heroTitle, systemImage: heroGlyph)
            }
        }
        .displayName("轻启快捷")
        .description("按一下，运行首页第一条快捷")
    }

    private var hero: WidgetShortcut? {
        OneTapShared.loadSnapshot()?.shortcuts.first
    }

    private var targetURL: URL {
        hero?.runURL ?? OneTapShared.homeURL
    }

    private var heroTitle: String {
        hero?.title ?? "打开轻启"
    }

    private var heroGlyph: String {
        hero?.glyph ?? "bolt.fill"
    }
}
