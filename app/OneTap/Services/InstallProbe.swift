import UIKit

/// 安装判断只有一条规则：scheme 在 Info.plist 白名单里才探。
/// 探不到（或不能探）都算「未验证」，不据此拦截执行，跑完再按真实结果回写。
@MainActor
enum InstallProbe {
    enum State {
        case installed
        case unverified

        var label: String {
            switch self {
            case .installed: return "已安装"
            case .unverified: return "未验证"
            }
        }
    }

    static func state(for app: CapabilityApp) -> State {
        guard
            let scheme = app.scheme,
            !scheme.isEmpty,
            querySchemes.contains(scheme),
            let url = URL(string: "\(scheme)://")
        else { return .unverified }
        return UIApplication.shared.canOpenURL(url) ? .installed : .unverified
    }

    private static let querySchemes: Set<String> = {
        let list = Bundle.main.object(forInfoDictionaryKey: "LSApplicationQueriesSchemes") as? [String]
        return Set(list ?? [])
    }()
}
