import SwiftUI

/// Navigation owner keeps the conversation model alive while the route is visible.
struct AIChatRouteView: View {
    @Bindable var session: AppSession
    @Binding var path: NavigationPath
    @State private var viewModel = ChatViewModel()

    var body: some View {
        NegativeOneScreen01View(viewModel: viewModel) {
            session.markMakeupGenerated()
            path.append(AppRoute.makeupPreview)
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }
}

struct NegativeOneScreen01View: View {
    @Bindable var viewModel: ChatViewModel
    var onMakeupReady: () -> Void = {}

    var body: some View {
        ChatConversationView(
            viewModel: viewModel,
            layoutMode: .full,
            onMakeupReady: onMakeupReady
        )
    }
}

#Preview {
    NegativeOneScreen01View(viewModel: ChatViewModel())
}
