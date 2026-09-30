import SwiftUI

struct AIChatTabView: View {
    @Bindable var session: AppSession
    let onClose: () -> Void
    @State private var viewModel: ChatViewModel?
    @State private var configurationError: String?

    var body: some View {
        Group {
            if let viewModel {
                NegativeOneScreen01View(viewModel: viewModel, onBack: onClose)
            } else if let configurationError {
                ContentUnavailableView(
                    "对话服务不可用",
                    systemImage: "exclamationmark.triangle",
                    description: Text(configurationError)
                )
            } else {
                ProgressView()
            }
        }
        .appDynamicBackground()
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            session.isAIChatPresented = true
            configureChatIfNeeded()
        }
        .onDisappear {
            session.isAIChatPresented = false
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 28)
                .onEnded { value in
                    let isHorizontal = abs(value.translation.width) > abs(value.translation.height)
                    if isHorizontal,
                       value.translation.width < -85,
                       value.predictedEndTranslation.width < -120 {
                        onClose()
                    }
                }
        )
    }

    private func configureChatIfNeeded() {
        guard viewModel == nil, configurationError == nil else { return }
        do {
            viewModel = try ChatCompositionRoot.makeViewModel()
        } catch {
            configurationError = error.localizedDescription
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
