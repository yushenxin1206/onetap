import Foundation

enum OpenVia: String, Equatable {
    case web
    case scheme
    case shortcutBridge

    var label: String {
        switch self {
        case .web: return "网页链接"
        case .scheme: return "App 链接"
        case .shortcutBridge: return "快捷指令"
        }
    }

    var runVia: RunVia {
        switch self {
        case .web: return .web
        case .scheme: return .scheme
        case .shortcutBridge: return .shortcut
        }
    }
}

enum RunFailure: Equatable {
    /// 网页地址被系统拒绝，可以手动用浏览器打开。
    case webRejected
    /// App 地址被拒绝，通常是目标 App 没装或路由改了。
    case routeBroken
    case noResponse
    case bridgeMissing
    case bridgeUnavailable

    var title: String {
        switch self {
        case .webRejected: return "网页入口没被接受"
        case .routeBroken: return "入口失效了"
        case .noResponse: return "没看到反应"
        case .bridgeMissing: return "还没建快捷指令"
        case .bridgeUnavailable: return "快捷指令不可用"
        }
    }

    var message: String {
        switch self {
        case .webRejected:
            return "系统没有接受这个网页入口。可以用浏览器打开，或复制链接到别处。"
        case .routeBroken:
            return "目标 App 可能没装，或它已经改了这个地址。"
        case .noResponse:
            return "链接被接受了，但 1.5 秒内没有离开轻启，目标 App 可能没有响应。"
        case .bridgeMissing:
            return "需要先在「快捷指令」App 里创建同名快捷指令，轻启才能调用它。"
        case .bridgeUnavailable:
            return "系统里没有可用的「快捷指令」App，无法走桥接。"
        }
    }
}

struct RunStep: Identifiable, Equatable {
    enum Status: Equatable {
        case todo
        case running
        case done
        case failed
    }

    let id = UUID()
    var title: String
    var detail: String?
    var status: Status = .todo
    var elapsed: TimeInterval?
}

struct RunSession: Identifiable {
    enum Phase: Equatable {
        case running
        case success
        case failure
    }

    let id = UUID()
    var shortcutID: UUID?
    var appID: String = ""
    var actionID: String = ""
    var title: String
    var appName: String
    var appGlyph: String
    var appTint: String
    var actionTitle: String
    var steps: [RunStep]
    var phase: Phase = .running
    var startedAt = Date()
    var elapsed: TimeInterval = 0
    var openVia: OpenVia?
    var failure: RunFailure?
    var failedStep: Int?

    // 失败页所需的上下文
    var url: String?
    var shortcutName: String?
    var capability: ActionCapability = .openOnly
    var opensAppRoot: Bool = false

    var progress: Double {
        switch phase {
        case .running:
            let done = steps.filter { $0.status == .done }.count
            let active = steps.contains { $0.status == .running } ? 0.5 : 0
            return min(0.96, (Double(done) + active) / Double(max(steps.count, 1)) + 0.08)
        case .success:
            return 1
        case .failure:
            return 1
        }
    }

    var formattedElapsed: String {
        String(format: "%.1fs", elapsed)
    }

    var successTitle: String {
        if openVia == .shortcutBridge { return "已交给快捷指令" }
        return "已打开 \(appName)"
    }

    var successDetail: String {
        if openVia == .shortcutBridge {
            let name = shortcutName ?? actionTitle
            return "轻启把动作交给了快捷指令「\(name)」。它是否真的执行成功，系统不向轻启回报。"
        }
        if openVia == .web {
            return "已在浏览器或目标 App 中打开网页。网页里的登录与后续操作，由浏览器和目标站点完成。"
        }
        if opensAppRoot {
            return "已打开 \(appName) 首页；后续操作需要你在 App 内完成。"
        }
        return "已经带你到目标页面。播放、扫码这些后续动作仍由 \(appName) 决定，轻启只确认已打开。"
    }
}

struct RunContext {
    var shortcutID: UUID?
    var title: String
    var app: CapabilityApp
    var action: CapabilityAction
}
