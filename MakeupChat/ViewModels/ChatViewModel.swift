import Foundation
import Observation

@Observable
@MainActor
final class ChatViewModel {
    private(set) var user: UserProfile?
    private(set) var messages: [ChatMessage] = []
    private(set) var conversationId: String?
    var inputText = ""
    private(set) var isSending = false
    private(set) var configurationError: String?

    private let store: AccountScopedChatStore
    private var sendTask: Task<Void, Never>?

    init(store: AccountScopedChatStore) {
        self.store = store
    }

    func reload() {
        do {
            let loaded = try store.load()
            user = loaded.0
            conversationId = loaded.1
            messages = loaded.2
            configurationError = nil
        } catch {
            configurationError = error.localizedDescription
        }
    }

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        inputText = ""
        startSend { try await self.store.sendNew(text: text) }
    }

    func retry(message: ChatMessage) {
        guard message.sender == .user, message.deliveryStatus.isRetryable, !isSending else { return }
        startSend { try await self.store.retry(localMessageId: message.id) }
    }

    func cancelPendingSend() {
        sendTask?.cancel()
        sendTask = nil
        isSending = false
        ChatSendRegistry.shared.unregister(userId: store.context.userId)
    }

    private func startSend(_ operation: @escaping @MainActor () async throws -> Void) {
        isSending = true
        sendTask = Task { [weak self] in
            guard let self else { return }
            ChatSendRegistry.shared.register(userId: self.store.context.userId) { [weak self] in
                self?.sendTask?.cancel()
            }
            defer {
                ChatSendRegistry.shared.unregister(userId: self.store.context.userId)
                self.isSending = false
                self.sendTask = nil
            }
            do {
                try await operation()
                guard SessionManager.shared.context?.userId == self.store.context.userId else { return }
                self.messages = (try? self.store.messages()) ?? self.messages
            } catch is CancellationError {
                // 登出或显式取消后不将状态写入其他账号的页面。
            } catch {
                guard SessionManager.shared.context?.userId == self.store.context.userId else { return }
                self.messages = (try? self.store.messages()) ?? self.messages
            }
        }
        messages = (try? store.messages()) ?? messages
    }
}
