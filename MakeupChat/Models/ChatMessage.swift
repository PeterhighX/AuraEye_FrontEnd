import Foundation

struct UserProfile: Identifiable {
    let userId: String
    var displayName: String
    var status: String
    var userFileJSON: String?
    var userPortraitPath: String?
    var uploadedPhotoPath: String?
    var eyePreviewPath: String?
    var eyeStepsJSON: String?

    var id: String { userId }

}

enum ChatSender: String {
    case ai
    case user
}

enum ChatDeliveryStatus: String {
    case sending
    case streaming
    case completed
    case failedRetryable = "failed_retryable"
    case failedPermanent = "failed_permanent"

    var isRetryable: Bool { self == .failedRetryable }
}

enum ChatReplyType: String, Codable, Sendable {
    case text
    case image
    case mixed
}

struct ChatAttachment: Identifiable, Codable, Sendable, Equatable {
    let id: String
    let type: String
    let source: String
    let thumbnailURL: String
    let contentURL: String
    let mimeType: String
    let width: Int
    let height: Int
    let expiresAt: Date?
    var localThumbnailPath: String?
    var localContentPath: String?
}

struct ChatMessage: Identifiable {
    let id: String
    let userId: String
    let conversationId: String
    let sender: ChatSender
    let text: String
    let replyType: ChatReplyType
    let attachments: [ChatAttachment]
    let aiAvatarName: String
    let clientRequestId: String?
    let serverMessageId: String?
    let serverRequestId: String?
    let deliveryStatus: ChatDeliveryStatus
    let errorCode: String?
    let errorDetail: String?
    let httpStatus: Int?
    let createdAt: Date
    let updatedAt: Date

    init(
        id: String = UUID().uuidString,
        userId: String,
        conversationId: String,
        sender: ChatSender,
        text: String,
        replyType: ChatReplyType = .text,
        attachments: [ChatAttachment] = [],
        aiAvatarName: String = "AvatarAI",
        clientRequestId: String? = nil,
        serverMessageId: String? = nil,
        serverRequestId: String? = nil,
        deliveryStatus: ChatDeliveryStatus,
        errorCode: String? = nil,
        errorDetail: String? = nil,
        httpStatus: Int? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.userId = userId
        self.conversationId = conversationId
        self.sender = sender
        self.text = text
        self.replyType = replyType
        self.attachments = attachments
        self.aiAvatarName = aiAvatarName
        self.clientRequestId = clientRequestId
        self.serverMessageId = serverMessageId
        self.serverRequestId = serverRequestId
        self.deliveryStatus = deliveryStatus
        self.errorCode = errorCode
        self.errorDetail = errorDetail
        self.httpStatus = httpStatus
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
