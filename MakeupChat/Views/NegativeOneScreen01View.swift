import SwiftUI

/// Navigation owner keeps the conversation model alive while the route is visible.
struct AIChatRouteView: View {
    @Bindable var session: AppSession
    @Binding var path: NavigationPath
    @State private var viewModel: ChatViewModel?
    @State private var configurationError: String?
    @State private var entranceOffset: CGFloat = -UIScreen.main.bounds.width
    @State private var isReturningHome = false

    var body: some View {
        Group {
            if let viewModel {
                NegativeOneScreen01View(viewModel: viewModel, onBack: returnToPreviousScreen)
            } else if let configurationError {
                ContentUnavailableView("对话服务不可用", systemImage: "exclamationmark.triangle", description: Text(configurationError))
            } else {
                ProgressView()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .simultaneousGesture(
            DragGesture(minimumDistance: 28)
                .onEnded { value in
                    let isHorizontal = abs(value.translation.width) > abs(value.translation.height)
                    if isHorizontal,
                       value.translation.width > 85,
                       value.predictedEndTranslation.width > 120 {
                        returnToPreviousScreen()
                    }
                }
        )
        .offset(x: entranceOffset)
        .onAppear {
            configureChatIfNeeded()
            withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                entranceOffset = 0
            }
        }
    }

    private func configureChatIfNeeded() {
        guard viewModel == nil, configurationError == nil else { return }
        do {
            viewModel = try ChatCompositionRoot.makeViewModel()
        } catch {
            configurationError = error.localizedDescription
        }
    }

    private func returnToPreviousScreen() {
        guard !path.isEmpty, !isReturningHome else { return }
        isReturningHome = true

        // 负一屏向右退出，保持“从左到右返回首页”的空间关系。
        withAnimation(.easeInOut(duration: 0.28)) {
            entranceOffset = UIScreen.main.bounds.width
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(280))
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                if !path.isEmpty {
                    path.removeLast()
                }
            }
        }
    }
}

struct NegativeOneScreen01View: View {
    @Bindable var viewModel: ChatViewModel
    var onBack: () -> Void = {}

    var body: some View {
        ChatConversationView(
            viewModel: viewModel,
            layoutMode: .full,
            onBack: onBack
        )
    }
}
