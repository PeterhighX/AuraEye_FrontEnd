import SwiftUI

struct NegativeOneScreen02View: View {
    @Bindable var viewModel: ChatViewModel

    var body: some View {
        ChatConversationView(viewModel: viewModel, layoutMode: .keyboard)
    }
}
