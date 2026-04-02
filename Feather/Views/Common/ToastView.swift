import SwiftUI

enum ToastStyle {
    case success, error, info

    var color: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        case .info: return .blue
        }
    }

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }
}

struct ToastData: Equatable {
    let message: String
    let style: ToastStyle
    let id: UUID = UUID()

    static func == (lhs: ToastData, rhs: ToastData) -> Bool {
        lhs.id == rhs.id
    }
}

struct ToastView: View {
    let data: ToastData

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: data.style.icon)
                .foregroundColor(.white)
                .font(.system(size: 16, weight: .semibold))
            Text(data.message)
                .foregroundColor(.white)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(data.style.color.opacity(0.9))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        )
    }
}

class ToastManager: ObservableObject {
    static let shared = ToastManager()

    @Published var currentToast: ToastData?
    private var dismissTask: Task<Void, Never>?

    func show(_ message: String, style: ToastStyle = .info) {
        dismissTask?.cancel()

        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                self.currentToast = ToastData(message: message, style: style)
            }
        }

        dismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                self.currentToast = nil
            }
        }
    }
}

struct ToastModifier: ViewModifier {
    @ObservedObject var manager = ToastManager.shared

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let toast = manager.currentToast {
                ToastView(data: toast)
                    .padding(.top, 50)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(999)
            }
        }
    }
}

extension View {
    func withToast() -> some View {
        modifier(ToastModifier())
    }
}
