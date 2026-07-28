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

enum ChatMessageKind: String {
    case text
    case photo
    case generating
    case eyePreview
}

enum ChatSender: String {
    case ai
    case user
}

struct ChatMessage: Identifiable {
    let id: String
    let sender: ChatSender
    let text: String
    let imageName: String?
    let imagePath: String?
    let aiAvatarName: String
    let kind: ChatMessageKind
    let createdAt: Date

    init(
        id: String = UUID().uuidString,
        sender: ChatSender,
        text: String,
        imageName: String? = nil,
        imagePath: String? = nil,
        aiAvatarName: String = "AvatarAI",
        kind: ChatMessageKind = .text,
        createdAt: Date = .now
    ) {
        self.id = id
        self.sender = sender
        self.text = text
        self.imageName = imageName
        self.imagePath = imagePath
        self.aiAvatarName = aiAvatarName
        self.kind = kind
        self.createdAt = createdAt
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

    var id: String { sku }
}
