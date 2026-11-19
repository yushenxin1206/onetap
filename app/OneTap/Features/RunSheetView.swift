import SwiftUI
import UIKit

@MainActor
struct RunSheetView: View {
    @EnvironmentObject private var runner: ShortcutRunner
    @EnvironmentObject private var toast: ToastCenter

    let session: RunSession

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Theme.ink.opacity(0.16))
                .frame(width: 36, height: 4)
                .padding(.top, 9)
                .padding(.bottom, 14)

            switch session.phase {
            case .running:
                runningContent
            case .success:
                successContent
            case .failure:
                failureContent
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 34)
        .frame(maxWidth: .infinity)
        .background(
            Theme.sheet,
            in: UnevenRoundedRectangle(
                topLeadingRadius: 32,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 32,
                style: .continuous
            )
        )
        .ignoresSafeArea(edges: .bottom)
        .animation(.easeInOut(duration: 0.22), value: session.steps)
        .animation(.easeInOut(duration: 0.22), value: session.phase)
    }

    // MARK: - 执行中

    private var runningContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                GlyphBadge(
                    symbol: session.appGlyph,
                    tint: Color(hexString: session.appTint),
                    size: 42
                )
                VStack(alignment: .leading, spacing: 3) {
                    Text(session.title)
                        .font(Theme.textFont(Theme.bodySize, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("\(session.appName) · \(session.actionTitle)")
                        .font(Theme.textFont(11.5))
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 5, height: 5)
                    Text("运行中")
                        .font(Theme.monoFont(10))
                        .kerning(0.6)
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(.bottom, 14)

            VStack(spacing: 0) {
                ForEach(Array(session.steps.enumerated()), id: \.element.id) { index, step in
                    stepRow(step, isLast: index == session.steps.count - 1)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.ink.opacity(0.07))
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: geo.size.width * session.progress)
                }
            }
            .frame(height: 3)
            .padding(.top, 16)

            Button {
                runner.cancel()
            } label: {
                Text("取消")
                    .font(Theme.textFont(12.5))
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
            }
            .buttonStyle(PressableStyle(scale: 0.95))
            .padding(.top, 10)
        }
    }

    private func stepRow(_ step: RunStep, isLast: Bool) -> some View {
        HStack(spacing: 11) {
            StepIndicator(status: step.status)

            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(Theme.textFont(13.5))
                    .foregroundStyle(
                        step.status == .todo ? Theme.muted :
                        step.status == .failed ? Theme.ink :
                        Theme.ink2
                    )
                    .lineLimit(1)
                if let detail = step.detail, !detail.isEmpty {
                    Text(detail)
                        .font(Theme.textFont(10.5))
                        .foregroundStyle(step.status == .failed ? Theme.accent : Theme.muted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if let elapsed = step.elapsed {
                Text(String(format: "%.1fs", elapsed))
                    .font(Theme.monoFont(10))
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(Theme.lineSoft).frame(height: 1)
            }
        }
    }

    // MARK: - 成功

    private var successContent: some View {
        VStack(spacing: 0) {
            resultIcon(symbol: "checkmark", background: Theme.greenSoft, tint: Theme.green)

            Text(session.successTitle)
                .font(Theme.displayFont(Theme.headlineSize))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .padding(.top, 16)

            Text(session.successDetail)
                .font(Theme.textFont(12.5))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 288)
                .padding(.top, 9)

            statPill("\(session.formattedElapsed) · \(session.openVia?.label ?? "打开")")
                .padding(.top, 16)

            VStack(spacing: 8) {
                Button {
                    runner.dismiss()
                } label: {
                    Text("知道了")
                        .font(Theme.textFont(13.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Theme.ink, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(PressableStyle(scale: 0.985))

                if session.url != nil {
                    Button(action: copyLink) {
                        Text("复制链接")
                            .font(Theme.textFont(13.5, weight: .medium))
                            .foregroundStyle(Theme.ink2)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(
                                Theme.ink.opacity(0.05),
                                in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                            )
                    }
                    .buttonStyle(PressableStyle(scale: 0.985))
                }
            }
            .padding(.top, 18)
        }
    }

    // MARK: - 失败

    private var failureContent: some View {
        VStack(spacing: 0) {
            resultIcon(
                symbol: "exclamationmark.triangle",
                background: Theme.accentSoft,
                tint: Theme.accent
            )

            Text(failureTitle)
                .font(Theme.displayFont(Theme.headlineSize))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .padding(.top, 16)

            Text(session.failure?.message ?? "")
                .font(Theme.textFont(12.5))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 288)
                .padding(.top, 9)

            statPill("\(session.formattedElapsed) · \(failureStat)")
                .padding(.top, 16)

            VStack(spacing: 8) {
                Button(action: primaryFailureAction) {
                    Text(primaryFailureTitle)
                        .font(Theme.textFont(13.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Theme.ink, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(PressableStyle(scale: 0.985))

                HStack(spacing: 8) {
                    if session.url != nil {
                        secondaryButton("复制链接", action: copyLink)
                    }
                    if session.failure == .routeBroken || session.failure == .noResponse {
                        secondaryButton("再试一次", action: { runner.retry() })
                    }
                }
            }
            .padding(.top, 18)

            Button {
                runner.dismiss()
            } label: {
                Text("关闭")
                    .font(Theme.textFont(11.5))
                    .foregroundStyle(Theme.muted)
                    .underline()
                    .padding(.vertical, 10)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - 组件

    private func resultIcon(symbol: String, background: Color, tint: Color) -> some View {
        ZStack {
            Circle().fill(background)
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: 64, height: 64)
        .padding(.top, 4)
    }

    private func statPill(_ text: String) -> some View {
        Text(text)
            .font(Theme.monoFont(10.5))
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Theme.paper.opacity(0.6),
                in: Capsule()
            )
            .overlay(Capsule().strokeBorder(Theme.lineSoft, lineWidth: 1))
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.textFont(13.5, weight: .medium))
                .foregroundStyle(Theme.ink2)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(
                    Theme.ink.opacity(0.05),
                    in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                )
        }
        .buttonStyle(PressableStyle(scale: 0.985))
    }

    // MARK: - 文案与动作

    private var failureTitle: String {
        session.failure?.title ?? "这次没成功"
    }

    private var failureStat: String {
        switch session.failure {
        case .webRejected: return "网页入口被拒绝"
        case .routeBroken: return "链接被拒绝"
        case .noResponse: return "1.5s 无响应"
        case .bridgeMissing: return "缺少快捷指令"
        case .bridgeUnavailable: return "快捷指令不可用"
        case .none: return "未知原因"
        }
    }

    private var primaryFailureTitle: String {
        switch session.failure {
        case .webRejected:
            return "用浏览器打开"
        case .routeBroken:
            return "再试一次"
        case .noResponse:
            return "再试一次"
        case .bridgeMissing:
            return "去创建快捷指令"
        case .bridgeUnavailable:
            return session.url == nil ? "关闭" : "复制链接"
        case .none:
            return "关闭"
        }
    }

    private func primaryFailureAction() {
        switch session.failure {
        case .webRejected:
            openWeb()
        case .routeBroken, .noResponse:
            runner.retry()
        case .bridgeMissing:
            openShortcutEditor()
        case .bridgeUnavailable:
            if session.url != nil { copyLink() } else { runner.dismiss() }
        case .none:
            runner.dismiss()
        }
    }

    private func copyLink() {
        guard let text = session.url else {
            toast.show("这条入口没有可复制的链接")
            return
        }
        UIPasteboard.general.string = text
        toast.show("链接已复制，可以粘贴到目标 App")
    }

    private func openWeb() {
        guard
            session.capability == .web,
            let raw = session.url,
            let url = URL(string: raw)
        else {
            toast.show("这条入口没有可用的网页版")
            return
        }
        UIApplication.shared.open(url)
    }

    private func openShortcutEditor() {
        guard let url = URL(string: "shortcuts://create-shortcut") else { return }
        UIApplication.shared.open(url)
    }
}

private struct StepIndicator: View {
    let status: RunStep.Status

    var body: some View {
        ZStack {
            switch status {
            case .done:
                Circle().fill(Theme.greenSoft)
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.green)
            case .running:
                Circle().strokeBorder(Theme.ink.opacity(0.14), lineWidth: 1.5)
                ProgressView()
                    .scaleEffect(0.5)
                    .tint(Theme.accent)
            case .failed:
                Circle().fill(Theme.accentSoft)
                Image(systemName: "exclamationmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.accent)
            case .todo:
                Circle().strokeBorder(Theme.ink.opacity(0.12), lineWidth: 1.5)
            }
        }
        .frame(width: 18, height: 18)
    }
}
