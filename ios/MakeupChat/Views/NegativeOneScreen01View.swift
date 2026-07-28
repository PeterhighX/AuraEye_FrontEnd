import SwiftUI

struct NegativeOneScreen01View: View {
    @Bindable var viewModel: ChatViewModel

    var body: some View {
        ChatConversationView(viewModel: viewModel, layoutMode: .full)
    }
}

#Preview {
    NegativeOneScreen01View(viewModel: ChatViewModel())
}
