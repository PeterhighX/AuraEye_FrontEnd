import ExyteChat
import SwiftUI

struct ChatConversationView: View {
    enum LayoutMode { case full, keyboard }

    @Bindable var viewModel: ChatViewModel
    let layoutMode: LayoutMode
    var onBack: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 24) {
                if let user = viewModel.user {
                    ProfileHeaderView(user: user, onBack: onBack)
                }
                TipBarView()
            }
            .padding(.top, 8)

            ChatView(messages: exyteMessages) { draft in
                _ = viewModel.send(text: draft.text)
            } messageBuilder: { parameters in
                if let message = viewModel.message(id: parameters.message.id) {
                    ChatBubbleView(message: message) {
                        viewModel.retry(message: message)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                } else {
                    parameters.defaultMessageView()
                }
            } inputViewBuilder: { parameters in
                MakeupInputBar(
                    text: parameters.text,
                    onSend: { parameters.inputViewActionClosure(.send) },
                    isSending: viewModel.isSending,
                    initialFocus: layoutMode == .keyboard
                )
                .background(.ultraThinMaterial)
            }
            .chatTheme(colors: .init(mainBG: .clear))
        }
        .onAppear(perform: viewModel.reload)
    }

    private var exyteMessages: [ExyteChat.Message] {
        let currentUser = ExyteChat.User(
            id: viewModel.user?.userId ?? "current-user",
            name: viewModel.user?.displayName ?? "我",
            avatarURL: nil,
            isCurrentUser: true
        )
        let assistant = ExyteChat.User(
            id: "auraeye-agent",
            name: "AuraEye",
            avatarURL: nil,
            isCurrentUser: false
        )

        return viewModel.messages.map { message in
            ExyteChat.Message(
                id: message.id,
                user: message.sender == .user ? currentUser : assistant,
                status: exyteStatus(for: message),
                createdAt: message.createdAt,
                // ExyteChat 会过滤完全没有内容的消息；零宽字符确保流式占位行存在，
                // 实际气泡仍读取领域模型中的空文本并展示“正在思考”。
                text: message.text.isEmpty ? "\u{200B}" : message.text
            )
        }
    }

    private func exyteStatus(for message: ChatMessage) -> ExyteChat.Message.Status {
        switch message.deliveryStatus {
        case .sending, .streaming:
            return .sending
        case .completed, .failedRetryable, .failedPermanent:
            return .sent
        }
    }
}
