import Foundation

protocol AIAgentServicing: Sendable {
    func stream(_ request: ChatSendRequest) -> AsyncThrowingStream<ChatStreamEvent, Error>
}

struct ChatSendRequest: Encodable, Sendable {
    let requestId: String
    let conversationId: String
    let message: String

    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case conversationId = "conversation_id"
        case message
    }
}

struct ChatReply: Sendable, Equatable {
    let clientRequestId: String
    let conversationId: String
    let messageId: String
    let message: String
    let avatarAsset: String
    let status: String
    let serverRequestId: String?
}

enum ChatStreamEvent: Sendable, Equatable {
    case accepted(messageId: String)
    case assistantStarted(messageId: String)
    case assistantDelta(String)
    case toolStarted(id: String, name: String)
    case toolCompleted(id: String, name: String, status: String)
    case completed(ChatReply)
    case failed(ChatStreamFailure)
}

struct ChatStreamFailure: Error, Sendable, Equatable {
    let code: String
    let detail: String
    let retryable: Bool
    let serverRequestId: String?
    let httpStatus: Int?
}

enum ChatContractError: LocalizedError {
    case invalidRequest
    case invalidResponse
    case mismatchedResponse

    var errorDescription: String? {
        switch self {
        case .invalidRequest: return "消息内容或标识不符合对话服务要求。"
        case .invalidResponse: return "对话服务返回格式异常。"
        case .mismatchedResponse: return "对话服务返回的会话或请求标识不匹配。"
        }
    }
}
