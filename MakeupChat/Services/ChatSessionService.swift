import Foundation
import UIKit

struct ChatRequestFailure: Sendable {
    let code: String
    let detail: String
    let httpStatus: Int?
    let retryable: Bool
    let serverRequestId: String?

    static func capture(_ error: Error) -> ChatRequestFailure {
        if let error = error as? ChatStreamFailure {
            return ChatRequestFailure(
                code: error.code,
                detail: error.detail,
                httpStatus: error.httpStatus,
                retryable: error.retryable,
                serverRequestId: error.serverRequestId
            )
        }
        if let error = error as? ChatContractError {
            return ChatRequestFailure(code: "CHAT_INVALID_RESPONSE", detail: error.localizedDescription, httpStatus: nil, retryable: false, serverRequestId: nil)
        }
        guard let error = error as? APIClientError else {
            return ChatRequestFailure(code: "NETWORK_UNAVAILABLE", detail: error.localizedDescription, httpStatus: nil, retryable: true, serverRequestId: nil)
        }
        switch error {
        case .networkUnavailable:
            return ChatRequestFailure(code: "NETWORK_UNAVAILABLE", detail: error.localizedDescription, httpStatus: nil, retryable: true, serverRequestId: nil)
        case let .problem(problem, metadata):
            let retryable = (problem.status == 503 && problem.code == "HERMES_UNAVAILABLE")
                || problem.status == 504
                || (problem.status == 502 && problem.retryable == true)
            return ChatRequestFailure(code: problem.code ?? "HTTP_\(problem.status)", detail: problem.detail ?? problem.title, httpStatus: problem.status, retryable: retryable, serverRequestId: metadata.serverRequestID ?? problem.requestId)
        case let .httpStatus(status, message, code, metadata):
            let retryable = (status == 502 && error.permitsControlledRetry)
                || (status == 503 && code == "HERMES_UNAVAILABLE")
                || status == 504
            return ChatRequestFailure(code: code ?? "HTTP_\(status)", detail: message, httpStatus: status, retryable: retryable, serverRequestId: metadata.serverRequestID)
        case let .invalidServerResponse(status, requestID):
            return ChatRequestFailure(code: "CHAT_INVALID_RESPONSE", detail: error.localizedDescription, httpStatus: status, retryable: false, serverRequestId: requestID)
        case .invalidResponse, .invalidImage:
            return ChatRequestFailure(code: "CHAT_INVALID_RESPONSE", detail: error.localizedDescription, httpStatus: nil, retryable: false, serverRequestId: nil)
        }
    }
}

@MainActor
final class AccountScopedChatStore {
    let context: SessionContext
    private let userRepository: UserRepository
    private let chatRepository: ChatRepository
    private let agentService: any AIAgentServicing
    private let assetDownloader: (any ChatAssetDownloading)?

    private(set) var user: UserProfile?
    private(set) var conversationId: String?

    init(
        context: SessionContext,
        agentService: any AIAgentServicing,
        assetDownloader: (any ChatAssetDownloading)? = nil,
        userRepository: UserRepository = UserRepository(),
        chatRepository: ChatRepository = ChatRepository()
    ) {
        self.context = context
        self.agentService = agentService
        self.assetDownloader = assetDownloader
        self.userRepository = userRepository
        self.chatRepository = chatRepository
    }

    func load() throws -> (UserProfile, String, [ChatMessage]) {
        let displayName = context.displayName.isEmpty ? context.username : context.displayName
        let user = try userRepository.upsertChatUser(userId: context.userId, displayName: displayName)
        let conversationId = try chatRepository.conversationID(for: context.userId)
        self.user = user
        self.conversationId = conversationId
        return (user, conversationId, try chatRepository.fetchMessages(userId: context.userId, conversationId: conversationId))
    }

    func prepareNew(text: String) throws -> ChatSendRequest {
        let request = try requireRequest(text: text, requestId: Self.makeRequestID())
        try chatRepository.insertSendingExchange(
            userId: context.userId,
            conversationId: request.conversationId,
            requestId: request.requestId,
            text: request.message
        )
        return request
    }

    func prepareRetry(localMessageId: String) throws -> ChatSendRequest {
        let conversationId = try requireConversationID()
        guard let request = try chatRepository.retryPayload(userId: context.userId, conversationId: conversationId, localMessageId: localMessageId) else {
            throw ChatStorageError.messageNotFound
        }
        try chatRepository.markRetrying(userId: context.userId, conversationId: conversationId, requestId: request.requestId)
        return request
    }

    func messages() throws -> [ChatMessage] {
        let conversationId = try requireConversationID()
        return try chatRepository.fetchMessages(userId: context.userId, conversationId: conversationId)
    }

    /// 下载失败不改变已完成消息的状态；下次进入页面会重新检查缺失文件。
    func downloadMissingAttachments(
        only attachmentID: String? = nil,
        onMessagesChanged: @MainActor () -> Void
    ) async {
        guard let assetDownloader,
              let messages = try? messages() else { return }
        let attachments = messages
            .flatMap(\.attachments)
            .filter { attachmentID == nil || $0.id == attachmentID }

        for attachment in attachments {
            guard !Task.isCancelled else { return }
            if !LocalMediaStore.fileExists(storedPath: attachment.localThumbnailPath) {
                do {
                    let path = try await cache(
                        attachment,
                        variant: .thumbnail,
                        downloader: assetDownloader
                    )
                    try chatRepository.updateAttachmentPaths(
                        userId: context.userId,
                        attachmentId: attachment.id,
                        localThumbnailPath: path
                    )
                    onMessagesChanged()
                } catch is CancellationError {
                    return
                } catch {
                    // 附件保留远端资产 ID，用户可稍后重试，不影响 Chat 成功终态。
                }
            }

            if !LocalMediaStore.fileExists(storedPath: attachment.localContentPath) {
                do {
                    let path = try await cache(
                        attachment,
                        variant: .full,
                        downloader: assetDownloader
                    )
                    try chatRepository.updateAttachmentPaths(
                        userId: context.userId,
                        attachmentId: attachment.id,
                        localContentPath: path
                    )
                    onMessagesChanged()
                } catch is CancellationError {
                    return
                } catch {
                    // 原图失败时仍可展示已落盘的缩略图，并在后续进入页面时重试。
                }
            }
        }
    }

    func perform(
        _ request: ChatSendRequest,
        onMessagesChanged: @MainActor () -> Void
    ) async throws {
        var accumulatedText = ""
        var lastFlush = Date.distantPast
        var failureWasPersisted = false

        do {
            for try await event in agentService.stream(request) {
                switch event {
                case let .accepted(messageId), let .assistantStarted(messageId):
                    try chatRepository.bindAssistantMessageID(
                        userId: context.userId,
                        conversationId: request.conversationId,
                        requestId: request.requestId,
                        messageId: messageId
                    )
                    onMessagesChanged()
                case let .assistantDelta(delta):
                    accumulatedText += delta
                    if Date().timeIntervalSince(lastFlush) >= 0.05 {
                        try chatRepository.replaceStreamingAssistantText(
                            userId: context.userId,
                            conversationId: request.conversationId,
                            requestId: request.requestId,
                            text: accumulatedText
                        )
                        lastFlush = .now
                        onMessagesChanged()
                    }
                case .toolStarted, .toolCompleted:
                    break
                case let .completed(reply):
                    try chatRepository.completeStreaming(
                        userId: context.userId,
                        conversationId: request.conversationId,
                        reply: reply
                    )
                    onMessagesChanged()
                    return
                case let .failed(failure):
                    failureWasPersisted = true
                    try chatRepository.discardStreamingAssistant(
                        userId: context.userId,
                        conversationId: request.conversationId,
                        requestId: request.requestId
                    )
                    try chatRepository.markFailed(
                        userId: context.userId,
                        conversationId: request.conversationId,
                        requestId: request.requestId,
                        failure: .capture(failure)
                    )
                    onMessagesChanged()
                    throw failure
                }
            }
            throw ChatContractError.invalidResponse
        } catch is CancellationError {
            try? chatRepository.discardStreamingAssistant(
                userId: context.userId,
                conversationId: request.conversationId,
                requestId: request.requestId
            )
            try? chatRepository.markFailed(
                userId: context.userId,
                conversationId: request.conversationId,
                requestId: request.requestId,
                failure: ChatRequestFailure(
                    code: "CHAT_CANCELLED",
                    detail: "发送已取消。",
                    httpStatus: nil,
                    retryable: true,
                    serverRequestId: nil
                )
            )
            throw CancellationError()
        } catch {
            if !failureWasPersisted {
                let failure = ChatRequestFailure.capture(error)
                try chatRepository.discardStreamingAssistant(
                    userId: context.userId,
                    conversationId: request.conversationId,
                    requestId: request.requestId
                )
                try chatRepository.markFailed(
                    userId: context.userId,
                    conversationId: request.conversationId,
                    requestId: request.requestId,
                    failure: failure
                )
                onMessagesChanged()
            }
            throw error
        }
    }

    private func requireRequest(text: String, requestId: String) throws -> ChatSendRequest {
        let message = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let conversationId = try requireConversationID()
        guard !message.isEmpty, message.count <= 4000 else { throw ChatContractError.invalidRequest }
        return ChatSendRequest(requestId: requestId, conversationId: conversationId, message: message)
    }

    private func requireConversationID() throws -> String {
        if let conversationId { return conversationId }
        _ = try load()
        guard let conversationId else { throw DatabaseError.executionFailed }
        return conversationId
    }

    private static func makeRequestID() -> String {
        "req_chat_\(UUID().uuidString.lowercased())"
    }

    private func cache(
        _ attachment: ChatAttachment,
        variant: ChatAssetVariant,
        downloader: any ChatAssetDownloading
    ) async throws -> String {
        let data = try await downloader.download(
            assetID: attachment.id,
            variant: variant,
            expectedMimeType: attachment.mimeType
        )
        guard UIImage(data: data) != nil else { throw APIClientError.invalidImage }
        let safeID = attachment.id.map { character in
            character.isLetter || character.isNumber || character == "-" || character == "_"
                ? String(character)
                : "_"
        }.joined()
        return try LocalMediaStore.saveData(
            data,
            bucket: .chatAttachments,
            fileName: "\(safeID)_\(variant.rawValue).\(fileExtension(for: attachment.mimeType))"
        )
    }

    private func fileExtension(for mimeType: String) -> String {
        switch mimeType {
        case "image/jpeg": return "jpg"
        case "image/webp": return "webp"
        default: return "png"
        }
    }
}

@MainActor
enum ChatCompositionRoot {
    static func makeViewModel() throws -> ChatViewModel {
        guard let context = SessionManager.shared.context else { throw APIConfigurationError.configurationMissing }
        let client = try APIEnvironment.shared.authenticatedClient(accessToken: context.accessToken)
        let service = RemoteAIAgentService(client: client)
        return ChatViewModel(store: AccountScopedChatStore(
            context: context,
            agentService: service,
            assetDownloader: service
        ))
    }
}

@MainActor
final class ChatSendRegistry {
    static let shared = ChatSendRegistry()
    private var cancelers: [String: () -> Void] = [:]

    func register(userId: String, cancel: @escaping () -> Void) { cancelers[userId] = cancel }
    func unregister(userId: String) { cancelers[userId] = nil }
    func cancel(userId: String) { cancelers.removeValue(forKey: userId)?() }
}
