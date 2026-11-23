import Foundation

/// 一条动作能做到什么，完全由地址形态推导，不单独存储。
enum ActionCapability: String, Hashable {
    case deepLink
    case openOnly
    case shortcut
    case web

    var label: String {
        switch self {
        case .deepLink: return "支持深链"
        case .openOnly: return "只能打开"
        case .shortcut: return "需快捷指令"
        case .web: return "网页"
        }
    }
}

/// 首次安装的铺底清单，只读 apps。
struct CapabilityManifest: Codable, Hashable {
    var apps: [CapabilityApp]
}

struct CapabilityApp: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var tagline: String
    var glyph: String
    var tint: String
    /// 目标 App 的根 scheme，只用于安装探测；可为空。
    var scheme: String?
    var actions: [CapabilityAction]

    var rootURL: String? {
        guard let scheme = scheme?.trimmingCharacters(in: .whitespacesAndNewlines), !scheme.isEmpty else {
            return nil
        }
        return "\(scheme)://"
    }

    /// 副标题行：有自定义 tagline 就显示它，否则按入口数量派生。
    var displayTagline: String {
        let trimmed = tagline.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return actions.isEmpty ? "还没有入口" : "\(actions.count) 个入口"
    }
}

struct CapabilityAction: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var subtitle: String?
    /// 唯一地址：网页地址或 App 地址；为空表示走快捷指令。
    var url: String?
    var shortcutName: String?

    var normalizedURL: String? {
        guard let raw = url?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        return raw
    }

    /// 只认快捷指令名、没有任何地址。
    var isBridge: Bool {
        guard
            let name = shortcutName?.trimmingCharacters(in: .whitespacesAndNewlines),
            !name.isEmpty
        else { return false }
        return normalizedURL == nil
    }

    var isWebURL: Bool {
        guard
            let raw = normalizedURL,
            let scheme = URLComponents(string: raw)?.scheme?.lowercased()
        else { return false }
        return scheme == "http" || scheme == "https"
    }

    /// 按地址形态推导能力标签，不再单独存 level / available。
    var capability: ActionCapability {
        if isBridge { return .shortcut }
        guard
            let raw = normalizedURL,
            let scheme = URLComponents(string: raw)?.scheme?.lowercased()
        else { return .openOnly }
        if scheme == "http" || scheme == "https" { return .web }
        if raw.lowercased() == "\(scheme)://" { return .openOnly }
        return .deepLink
    }

    static func isValid(url raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmed.isEmpty,
            let components = URLComponents(string: trimmed),
            let scheme = components.scheme,
            !scheme.isEmpty
        else { return false }
        if scheme.lowercased() == "http" || scheme.lowercased() == "https" {
            return !(components.host ?? "").isEmpty
        }
        return true
    }
}
