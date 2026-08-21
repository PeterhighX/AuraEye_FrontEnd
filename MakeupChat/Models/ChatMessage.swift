import Foundation

struct UserProfile: Identifiable {
    let userId: String
    var displayName: String
    var status: String
    var credits: Int
    var userFileJSON: String?
    var userPortraitPath: String?
    var uploadedPhotoPath: String?
    var eyePreviewPath: String?
    var eyeStepsJSON: String?

    var id: String { userId }

    var tipText: String {
        guard
            let userFileJSON,
            let data = userFileJSON.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let brush = json["brushTip"] as? String
        else {
            return "毛刷的作用可以柔化边缘，但是要定时清理哦！"
        }
        return brush
    }
}

enum ChatSender: String {
    case ai
    case user
}

enum ChatDeliveryStatus: String {
    case sending
    case completed
    case failedRetryable = "failed_retryable"
    case failedPermanent = "failed_permanent"

    var isRetryable: Bool { self == .failedRetryable }
}

struct ChatMessage: Identifiable {
    let id: String
    let userId: String
    let conversationId: String
    let sender: ChatSender
    let text: String
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

struct EyeStyle: Identifiable {
    let eyeStyleName: String
    let eyeSVG: String?
    let eyelinerName: String?
    let eyelinerSVG: String?
    let eyeColorMain: String?
    let eyeColorSub: String?
    let scene: String?

    var id: String { eyeStyleName }
}

struct CosmeticItem: Identifiable {
    let sku: String
    let makeupCategory: String
    let makeupTab: String?
    let makeupColorsJSON: String?
    let brushJSON: String?
    var previewPath: String?

    var id: String { sku }
}
