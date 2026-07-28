import Foundation
import UIKit

/// 串联聊天与用户/眼型/化妆品数据库的业务层（纯本地）
final class ChatSessionService {
    private let userRepository: UserRepository
    private let chatRepository: ChatRepository
    private let cosmeticsRepository: CosmeticsRepository
    private let eyeStyleRepository: EyeStyleRepository

    init(
        userRepository: UserRepository = UserRepository(),
        chatRepository: ChatRepository = ChatRepository(),
        cosmeticsRepository: CosmeticsRepository = CosmeticsRepository(),
        eyeStyleRepository: EyeStyleRepository = EyeStyleRepository()
    ) {
        self.userRepository = userRepository
        self.chatRepository = chatRepository
        self.cosmeticsRepository = cosmeticsRepository
        self.eyeStyleRepository = eyeStyleRepository
    }

    func loadSession() throws -> (UserProfile, [ChatMessage]) {
        let user = try userRepository.currentUser()
        let messages = try chatRepository.fetchMessages(userId: user.userId)
        return (user, messages)
    }

    func sendUserText(_ text: String, user: UserProfile) throws -> (ChatMessage, [ChatMessage]) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ChatSessionError.emptyMessage
        }

        let userMessage = ChatMessage(sender: .user, text: trimmed)
        try chatRepository.insert(userMessage, userId: user.userId)

        let replies = try buildAIReplies(for: trimmed, user: user)
        for reply in replies {
            try chatRepository.insert(reply, userId: user.userId)
        }

        return (userMessage, replies)
    }

    func sendSuggestion(_ suggestion: String, user: UserProfile) throws -> (ChatMessage, [ChatMessage]) {
        try sendUserText(suggestion, user: user)
    }

    func persistUserText(_ text: String, user: UserProfile) throws -> ChatMessage {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ChatSessionError.emptyMessage
        }

        let message = ChatMessage(sender: .user, text: trimmed)
        try chatRepository.insert(message, userId: user.userId)
        return message
    }

    func persistAIResponse(_ response: AIAgentResponse, user: UserProfile) throws -> ChatMessage {
        let message = ChatMessage(
            sender: .ai,
            text: response.text,
            aiAvatarName: response.avatarName
        )
        try chatRepository.insert(message, userId: user.userId)
        return message
    }

    func attachDemoPhoto(user: UserProfile) throws -> (ChatMessage, [ChatMessage]) {
        let photoPath = try persistDemoPhoto()
        return try attachStoredPhoto(path: photoPath, user: user)
    }

    func attachPhoto(_ image: UIImage, user: UserProfile) throws -> (ChatMessage, [ChatMessage]) {
        let photoPath = try LocalMediaStore.saveImage(
            image,
            bucket: .uploads,
            fileName: "user_update_photo_\(user.userId).jpg"
        )
        return try attachStoredPhoto(path: photoPath, user: user)
    }

    private func attachStoredPhoto(
        path photoPath: String,
        user: UserProfile
    ) throws -> (ChatMessage, [ChatMessage]) {
        try userRepository.updateUploadedPhoto(userId: user.userId, path: photoPath)

        let userMessage = ChatMessage(
            sender: .user,
            text: "铛铛！这是我的图片",
            imageName: nil,
            imagePath: photoPath,
            kind: .photo
        )
        try chatRepository.insert(userMessage, userId: user.userId)

        let replies = try buildAIReplies(for: "__photo_uploaded__", user: user)
        for reply in replies {
            try chatRepository.insert(reply, userId: user.userId)
        }

        return (userMessage, replies)
    }

    func cosmeticTip() -> String {
        (try? cosmeticsRepository.brushTip()) ?? "毛刷的作用可以柔化边缘，但是要定时清理哦！"
    }

    private func buildAIReplies(for input: String, user: UserProfile) throws -> [ChatMessage] {
        if input == "__photo_uploaded__" {
            let style = try eyeStyleRepository.fetch(scene: "日常")
            let styleName = style?.eyeStyleName ?? "1color42"
            let scene = style?.scene ?? "日常"

            let previewPath = try persistPlaceholderPreview(userId: user.userId)
            let stepsJSON = "[\"step_eye.svg\",\"step_liner.svg\",\"step_blush.svg\"]"
            try userRepository.updateEyePreview(
                userId: user.userId,
                previewPath: previewPath,
                stepsJSON: stepsJSON
            )

            return [
                ChatMessage(
                    sender: .ai,
                    text: "好的！这就结合您今日的天气给您推荐合适的妆容！！",
                    aiAvatarName: "AvatarAI2"
                ),
                ChatMessage(
                    sender: .ai,
                    text: "已匹配眼型 \(styleName)，适合\(scene)场景。专属妆容效果正在生成中…",
                    aiAvatarName: "AvatarAI2",
                    kind: .generating
                )
            ]
        }

        if input.contains("图片") || input.contains("照片") {
            return [
                ChatMessage(
                    sender: .ai,
                    text: "收到！请点击相机按钮上传一张照片，我会结合您的 User_update_photo 档案生成妆容。",
                    aiAvatarName: "AvatarAI"
                )
            ]
        }

        if input.contains("清新") {
            return [
                ChatMessage(
                    sender: .ai,
                    text: "明白啦，我会从眼型库挑选更清新的配色，并参考您档案里的肤色偏好。",
                    aiAvatarName: "AvatarAI2"
                )
            ]
        }

        if input.contains("正式") {
            return [
                ChatMessage(
                    sender: .ai,
                    text: "好的，我会推荐更适合正式场合的眼线与底妆步骤。",
                    aiAvatarName: "AvatarAI2"
                )
            ]
        }

        return [
            ChatMessage(
                sender: .ai,
                text: "好的，我已经把这条消息写入 chat_messages 表。上传照片后我会更新 Eye_Preview 和 Eye_Step。",
                aiAvatarName: "AvatarAI"
            )
        ]
    }

    private func persistDemoPhoto() throws -> String {
        let stored = "media/uploads/user_update_photo.png"
        if LocalMediaStore.fileExists(storedPath: stored) {
            return stored
        }
        return try LocalMediaStore.saveBundledImage(
            named: "ParkPhoto",
            bucket: .uploads,
            fileName: "user_update_photo.png"
        )
    }

    private func persistPlaceholderPreview(userId: String) throws -> String {
        let fileName = "eye_preview_\(userId).txt"
        let stored = "media/eyePreviews/\(fileName)"
        if LocalMediaStore.fileExists(storedPath: stored) {
            return stored
        }
        return try LocalMediaStore.saveText(
            "eye_preview_placeholder",
            bucket: .eyePreviews,
            fileName: fileName
        )
    }
}

enum ChatSessionError: Error {
    case emptyMessage
}
