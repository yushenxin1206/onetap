import SwiftUI
import UIKit

/// 只能通过「轻启是否离开前台」推断唤起成功。
/// 1.5 秒内没有离开，就当成没反应，而不是假装成功。
@MainActor
final class SceneDepartureSignal {
    private var continuation: CheckedContinuation<Bool, Never>?
    private var timeoutTask: Task<Void, Never>?

    func waitForDeparture(timeout: TimeInterval) async -> Bool {
        if UIApplication.shared.applicationState != .active { return true }
        return await withCheckedContinuation { cont in
            continuation = cont
            timeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                guard !Task.isCancelled else { return }
                self?.resolve(false)
            }
        }
    }

    func departed() {
        resolve(true)
    }

    func cancel() {
        resolve(false)
    }

    private func resolve(_ value: Bool) {
        guard let cont = continuation else { return }
        continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        cont.resume(returning: value)
    }
}

@MainActor
final class ShortcutRunner: ObservableObject {
    @Published private(set) var session: RunSession?

    private var task: Task<Void, Never>?
    private let signal = SceneDepartureSignal()
    private var context: RunContext?
    private var stepStartedAt: [Int: Date] = [:]

    private let departureTimeout: TimeInterval = 1.5

    func start(context: RunContext) {
        task?.cancel()
        signal.cancel()
        self.context = context
        stepStartedAt = [:]

        var newSession = RunSession(
            shortcutID: context.shortcutID,
            appID: context.app.id,
            actionID: context.action.id,
            title: context.title,
            appName: context.app.name,
            appGlyph: context.app.glyph,
            appTint: context.app.tint,
            actionTitle: context.action.title,
            steps: [
                RunStep(title: "检查 \(context.app.name) 是否安装"),
                RunStep(title: "唤起 \(context.app.name)"),
                RunStep(title: "等待系统交还"),
                RunStep(title: "记录这次结果")
            ]
        )
        newSession.url = context.action.normalizedURL
        newSession.shortcutName = context.action.shortcutName
        newSession.capability = context.action.capability
        newSession.opensAppRoot = context.action.capability == .openOnly
        session = newSession

        task = Task { [weak self] in
            await self?.perform(context)
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        signal.cancel()
        session = nil
    }

    func dismiss() {
        task?.cancel()
        task = nil
        session = nil
    }

    func retry() {
        guard let context else { return }
        start(context: context)
    }

    func handleScenePhase(_ phase: ScenePhase) {
        guard phase != .active else { return }
        signal.departed()
    }

    private func perform(_ context: RunContext) async {
        let started = Date()
        let app = context.app
        let action = context.action

        // 1. 检查安装 / 桥接可用性
        setStep(0, status: .running)
        try? await Task.sleep(nanoseconds: 240_000_000)
        if Task.isCancelled { return }

        if let name = action.shortcutName, action.isBridge {
            guard canRunShortcuts else {
                fail(.bridgeUnavailable, at: 0, started: started)
                return
            }
            setStep(0, status: .done, detail: "快捷指令可用")

            // 2. 交给快捷指令（名称做百分号编码）
            setStep(1, status: .running, detail: "「\(name)」")
            let url = Self.shortcutURL(name: name)
            let opened = await open(url, universalLinksOnly: false)
            if Task.isCancelled { return }
            guard opened else {
                fail(.bridgeMissing, at: 1, started: started)
                return
            }
            setStep(1, status: .done, detail: "已交给快捷指令")

            // 3. 只能确认是否离开轻启
            setStep(2, status: .running)
            let departed = await signal.waitForDeparture(timeout: departureTimeout)
            if Task.isCancelled { return }
            if departed {
                setStep(2, status: .done, detail: "已离开轻启")
                succeed(via: .shortcutBridge, started: started)
            } else {
                fail(.noResponse, at: 2, started: started)
            }
            return
        }

        // 统一规则：scheme 在白名单里才探；探不到或不能探都记「未验证」，继续尝试。
        switch InstallProbe.state(for: app) {
        case .installed:
            setStep(0, status: .done, detail: "已确认安装")
        case .unverified:
            setStep(0, status: .done, detail: "未验证，直接尝试")
        }

        // 2. 一条动作只尝试一次：网页走 Universal Link，App 地址直接打开。
        setStep(1, status: .running)
        guard let raw = action.normalizedURL, let url = URL(string: raw) else {
            setStep(1, status: .failed, detail: "没有可用的地址")
            fail(.routeBroken, at: 1, started: started, keepStep: true)
            return
        }

        let isWeb = action.isWebURL
        var opened = await open(url, universalLinksOnly: isWeb)
        // 网页地址被 Universal Link 拒绝时，直接交给浏览器，不报失败。
        if isWeb && !opened {
            opened = await open(url, universalLinksOnly: false)
        }
        if Task.isCancelled { return }

        guard opened else {
            setStep(1, status: .failed, detail: isWeb ? "系统没有接受网页入口" : "链接没有被系统接受")
            fail(isWeb ? .webRejected : .routeBroken, at: 1, started: started, keepStep: true)
            return
        }

        let via: OpenVia = isWeb ? .web : .scheme
        setStep(1, status: .done, detail: isWeb ? "已交给浏览器" : "已通过\(via.label)唤起")

        // 3. 等 1.5 秒，看轻启是否真的退到后台
        setStep(2, status: .running)
        let departed = await signal.waitForDeparture(timeout: departureTimeout)
        if Task.isCancelled { return }
        if departed {
            setStep(2, status: .done, detail: "已离开轻启")
            succeed(via: via, started: started)
        } else {
            fail(.noResponse, at: 2, started: started)
        }
    }

    private func succeed(via: OpenVia, started: Date) {
        guard var current = session else { return }
        current.openVia = via
        current.phase = .success
        current.elapsed = Date().timeIntervalSince(started)
        if let index = current.steps.indices.last {
            current.steps[index].status = .done
            current.steps[index].detail = via == .shortcutBridge ? "只能确认已交给快捷指令" : "只能确认已唤起"
            current.steps[index].elapsed = current.elapsed
        }
        session = current
    }

    private func fail(_ reason: RunFailure, at index: Int, started: Date, keepStep: Bool = false) {
        guard var current = session else { return }
        current.phase = .failure
        current.failure = reason
        current.failedStep = index
        current.elapsed = Date().timeIntervalSince(started)
        if !keepStep {
            current.steps[index].status = .failed
            current.steps[index].detail = reason == .noResponse ? "1.5 秒内没有离开轻启" : nil
        }
        current.steps[index].elapsed = current.elapsed
        session = current
    }

    private func setStep(_ index: Int, status: RunStep.Status, detail: String? = nil) {
        guard var current = session, current.steps.indices.contains(index) else { return }
        if status == .running {
            stepStartedAt[index] = Date()
        }
        current.steps[index].status = status
        if let detail { current.steps[index].detail = detail }
        if let start = stepStartedAt[index] {
            current.steps[index].elapsed = Date().timeIntervalSince(start)
        }
        session = current
    }

    private var canRunShortcuts: Bool {
        guard let url = URL(string: "shortcuts://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    private func open(_ url: URL, universalLinksOnly: Bool) async -> Bool {
        await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            UIApplication.shared.open(url, options: [.universalLinksOnly: universalLinksOnly]) { ok in
                cont.resume(returning: ok)
            }
        }
    }

    /// 快捷指令名通常是中文，URLComponents 会做百分号编码。
    static func shortcutURL(name: String) -> URL {
        var components = URLComponents(string: "shortcuts://run-shortcut")!
        components.queryItems = [URLQueryItem(name: "name", value: name)]
        return components.url ?? URL(string: "shortcuts://")!
    }
}
