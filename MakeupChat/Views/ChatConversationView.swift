import SwiftUI

struct ChatConversationView: View {
    enum LayoutMode { case full, keyboard }

    @Bindable var viewModel: ChatViewModel
    let layoutMode: LayoutMode
    var onBack: () -> Void = {}

    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 24) {
                if let user = viewModel.user {
                    ProfileHeaderView(user: user, onBack: onBack)
                }
                TipBarView()
            }
            .padding(.top, 8)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 18) {
                        ForEach(viewModel.messages) { message in
                            ChatBubbleView(message: message) {
                                viewModel.retry(message: message)
                            }
                            .id(message.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, layoutMode == .full ? 120 : 24)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    guard let last = viewModel.messages.last else { return }
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    if last.sender == .ai { isInputFocused = false }
                }
            }
            .frame(maxHeight: layoutMode == .keyboard ? .infinity : nil, alignment: .bottom)

            if layoutMode == .full { Spacer(minLength: 0) }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MakeupInputBar(
                text: $viewModel.inputText,
                focusBinding: $isInputFocused,
                onSend: viewModel.sendMessage,
                isSending: viewModel.isSending,
                isKeyboardPresented: isInputFocused
            )
            .background {
                Rectangle()
                    .fill(isInputFocused ? AnyShapeStyle(Color.clear) : AnyShapeStyle(.ultraThinMaterial))
                    .ignoresSafeArea(edges: .bottom)
            }
        }
        .animation(.easeOut(duration: 0.18), value: isInputFocused)
        .onAppear {
            viewModel.reload()
            isInputFocused = layoutMode == .keyboard
        }
    }
}
