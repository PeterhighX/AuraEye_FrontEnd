import Foundation
import Observation

@Observable
@MainActor
final class ChatViewModel {
    private(set) var user: UserProfile?
    private(set) var messages: [ChatMessage] = []
    private(set) var conversationId: String?
    private(set) var isSending = false
    private(set) var configurationError: String?

    private let store: AccountScopedChatStore
    private var sendTask: Task<Void, Never>?
    private var attachmentDownloadTask: Task<Void, Never>?

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
            refreshMissingAttachments()
        } catch {
            configurationError = error.localizedDescription
        }
    }

    @discardableResult
    func send(text: String) -> Bool {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return false }
        do {
            let request = try store.prepareNew(text: text)
            messages = try store.messages()
            startSend(request)
            return true
        } catch {
            configurationError = error.localizedDescription
            return false
        }
    }

    func retry(message: ChatMessage) {
        guard message.sender == .user, message.deliveryStatus.isRetryable, !isSending else { return }
        do {
            let request = try store.prepareRetry(localMessageId: message.id)
            messages = try store.messages()
            startSend(request)
        } catch {
            configurationError = error.localizedDescription
        }
    }

    func retry(attachment: ChatAttachment) {
        refreshMissingAttachments(only: attachment.id)
    }

    func cancelPendingSend() {
        sendTask?.cancel()
        attachmentDownloadTask?.cancel()
        sendTask = nil
        attachmentDownloadTask = nil
        isSending = false
        ChatSendRegistry.shared.unregister(userId: store.context.userId)
    }

    func message(id: String) -> ChatMessage? {
        messages.first { $0.id == id }
    }

    private func startSend(_ request: ChatSendRequest) {
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
                try await self.store.perform(request) { [weak self] in
                    guard let self,
                          SessionManager.shared.context?.userId == self.store.context.userId else { return }
                    self.messages = (try? self.store.messages()) ?? self.messages
                }
                guard SessionManager.shared.context?.userId == self.store.context.userId else { return }
                self.messages = (try? self.store.messages()) ?? self.messages
                self.refreshMissingAttachments()
            } catch is CancellationError {
                // 登出或显式取消后不将状态写入其他账号的页面。
            } catch {
                guard SessionManager.shared.context?.userId == self.store.context.userId else { return }
                self.messages = (try? self.store.messages()) ?? self.messages
            }
        }
    }

    private func refreshMissingAttachments(only attachmentID: String? = nil) {
        attachmentDownloadTask?.cancel()
        attachmentDownloadTask = Task { [weak self] in
            guard let self else { return }
            await self.store.downloadMissingAttachments(only: attachmentID) { [weak self] in
                guard let self,
                      SessionManager.shared.context?.userId == self.store.context.userId else { return }
                self.messages = (try? self.store.messages()) ?? self.messages
            }
        }
    }
}
