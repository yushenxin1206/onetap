import SwiftUI
import WidgetKit

@main
struct OneTapWidgetBundle: WidgetBundle {
    var body: some Widget {
        ShortcutWidget()
        LockShortcutWidget()
        LockHeroShortcutWidget()
        if #available(iOS 18.0, *) {
            OneTapControl()
        }
    }
}
