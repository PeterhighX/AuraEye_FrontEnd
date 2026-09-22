import Foundation

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

    private(set) var user: UserProfile?
    private(set) var conversationId: String?

    init(
        context: SessionContext,
        agentService: any AIAgentServicing,
        userRepository: UserRepository = UserRepository(),
        chatRepository: ChatRepository = ChatRepository()
    ) {
        self.context = context
        self.agentService = agentService
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
}

@MainActor
enum ChatCompositionRoot {
    static func makeViewModel() throws -> ChatViewModel {
        guard let context = SessionManager.shared.context else { throw APIConfigurationError.configurationMissing }
        let client = try APIEnvironment.shared.authenticatedClient(accessToken: context.accessToken)
        return ChatViewModel(store: AccountScopedChatStore(context: context, agentService: RemoteAIAgentService(client: client)))
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
