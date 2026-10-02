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

struct ChatImageAttachment: Hashable, Sendable {
    let id: String
    let thumbnailURL: URL
    let fullURL: URL

    init(id: String = UUID().uuidString, thumbnailURL: URL, fullURL: URL? = nil) {
        self.id = id
        self.thumbnailURL = thumbnailURL
        self.fullURL = fullURL ?? thumbnailURL
    }
}

struct ChatMessage: Identifiable {
    let id: String
    let userId: String
    let conversationId: String
    let sender: ChatSender
    let text: String
    let imageAttachments: [ChatImageAttachment]
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
        imageAttachments: [ChatImageAttachment] = [],
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
        self.imageAttachments = imageAttachments
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
