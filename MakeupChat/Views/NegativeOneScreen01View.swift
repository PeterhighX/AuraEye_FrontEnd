import SwiftUI

/// Navigation owner keeps the conversation model alive while the route is visible.
struct AIChatRouteView: View {
    @Bindable var session: AppSession
    @Binding var path: NavigationPath
    @State private var viewModel = ChatViewModel()
    @State private var entranceOffset: CGFloat = -UIScreen.main.bounds.width
    @State private var isReturningHome = false

    var body: some View {
        NegativeOneScreen01View(
            viewModel: viewModel,
            onBack: returnToPreviousScreen
        ) {
            session.markMakeupGenerated()
            path.append(AppRoute.makeupPreview)
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
            withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                entranceOffset = 0
            }
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
    var onMakeupReady: () -> Void = {}

    var body: some View {
        ChatConversationView(
            viewModel: viewModel,
            layoutMode: .full,
            onBack: onBack,
            onMakeupReady: onMakeupReady
        )
    }
}

#Preview {
    NegativeOneScreen01View(viewModel: ChatViewModel())
}
