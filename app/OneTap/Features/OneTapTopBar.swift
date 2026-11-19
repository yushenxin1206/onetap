import SwiftUI

/// 全 App 统一的顶部条：左圆形关闭、中标题、右圆形主操作。
struct OneTapTopBar: View {
    let title: String
    let onClose: () -> Void
    var actionIcon: String?
    var actionLabel: String?
    var isActionEnabled: Bool = true
    var onAction: (() -> Void)?

    var body: some View {
        ZStack {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.ink)

            HStack(spacing: 0) {
                TopBarIconButton(
                    icon: "xmark",
                    label: "关闭",
                    style: .neutral,
                    action: onClose
                )

                Spacer(minLength: 0)

                if let actionIcon, let onAction {
                    TopBarIconButton(
                        icon: actionIcon,
                        label: actionLabel ?? "",
                        style: .accent,
                        action: onAction
                    )
                    .opacity(isActionEnabled ? 1 : 0.35)
                    .disabled(!isActionEnabled)
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 48)
    }
}

private struct TopBarIconButton: View {
    enum Style {
        case neutral
        case accent
    }

    let icon: String
    let label: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(style == .neutral ? Theme.ink.opacity(0.6) : Theme.accent)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
