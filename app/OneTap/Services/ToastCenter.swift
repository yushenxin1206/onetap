import SwiftUI

@MainActor
final class ToastCenter: ObservableObject {
    @Published private(set) var message: String?

    private var hideTask: Task<Void, Never>?

    func show(_ text: String) {
        hideTask?.cancel()
        withAnimation(Theme.sheetAnimation) {
            message = text
        }
        hideTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_900_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                self?.message = nil
            }
        }
    }
}
