import Foundation

protocol AIAgentServicing: Sendable {
    func send(_ request: ChatSendRequest) async throws -> ChatReply
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
