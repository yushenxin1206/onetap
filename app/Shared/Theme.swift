import SwiftUI

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    /// 能力清单里用 "#RRGGBB" 描述品牌色，解析失败时退回墨色。
    init(hexString: String) {
        let cleaned = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else {
            self = Theme.ink
            return
        }
        self.init(hex: value)
    }
}

/// 设计 token：背景 #F2F0EA / 卡面 #FFFFFF / 墨色 #141413 / 强调 #FF5A1F
/// 圆角 28 / 22 / 16，字号 34 / 22 / 15 / 12，
/// Sheet 320ms cubic-bezier(.32,.72,0,1)，按压 120ms。
enum Theme {
    static let bg = Color(hex: 0xF2F0EA)
    static let bgDeep = Color(hex: 0xEBE8E1)
    static let paper = Color.white
    static let ink = Color(hex: 0x141413)
    static let ink2 = Color(hex: 0x3B3B37)
    static let muted = Color(hex: 0x8B8A82)
    static let line = Color(hex: 0x141413, alpha: 0.12)
    static let lineSoft = Color(hex: 0x141413, alpha: 0.07)
    static let accent = Color(hex: 0xFF5A1F)
    static let accentSoft = Color(hex: 0xFFEBE2)
    static let green = Color(hex: 0x1FA365)
    static let greenSoft = Color(hex: 0xE3F5EC)
    static let blueSoft = Color(hex: 0xE8EFFD)
    static let sheet = Color(hex: 0xFBFAF7)

    static let radiusLarge: CGFloat = 28
    static let radiusMedium: CGFloat = 22
    static let radiusSmall: CGFloat = 16

    static let titleSize: CGFloat = 34
    static let headlineSize: CGFloat = 22
    static let bodySize: CGFloat = 15
    static let captionSize: CGFloat = 12

    static let sheetAnimation = Animation.timingCurve(0.32, 0.72, 0, 1, duration: 0.32)
    static let pressAnimation = Animation.easeOut(duration: 0.12)

    static func displayFont(_ size: CGFloat = titleSize) -> Font {
        .system(size: size, weight: .semibold)
    }

    static func textFont(_ size: CGFloat = bodySize, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    static func monoFont(_ size: CGFloat = 10, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

/// 统一的卡片描边 + 极轻投影。
struct CardSurface: ViewModifier {
    var radius: CGFloat = Theme.radiusMedium
    var fill: Color = Theme.paper

    func body(content: Content) -> some View {
        content
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.lineSoft, lineWidth: 1)
            )
            .shadow(color: Theme.ink.opacity(0.04), radius: 1, x: 0, y: 1)
    }
}

extension View {
    func cardSurface(radius: CGFloat = Theme.radiusMedium, fill: Color = Theme.paper) -> some View {
        modifier(CardSurface(radius: radius, fill: fill))
    }
}

/// 按压 120ms 的轻微缩放，对应设计稿的 :active。
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.975

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(Theme.pressAnimation, value: configuration.isPressed)
    }
}

struct GlyphBadge: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 36
    var fillOpacity: Double = 0.13

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            .fill(tint.opacity(fillOpacity))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: size * 0.46, weight: .semibold))
                    .foregroundStyle(tint)
            )
    }
}

struct CapabilityTag: View {
    let capability: ActionCapability

    var body: some View {
        Text(capability.label)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(foreground)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(background, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    private var foreground: Color {
        switch capability {
        case .deepLink: return Color(hex: 0x177A4C)
        case .openOnly: return Color(hex: 0x6E6D66)
        case .shortcut: return Color(hex: 0xA2400F)
        case .web: return Color(hex: 0x2E6BE6)
        }
    }

    private var background: Color {
        switch capability {
        case .deepLink: return Theme.greenSoft
        case .openOnly: return Theme.ink.opacity(0.05)
        case .shortcut: return Theme.accentSoft
        case .web: return Theme.blueSoft
        }
    }
}
