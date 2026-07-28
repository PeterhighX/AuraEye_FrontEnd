import Foundation
import Observation
import UIKit

@Observable
@MainActor
final class ChatViewModel {
    private(set) var user: UserProfile
    private(set) var messages: [ChatMessage] = []
    private(set) var tipText: String = ""
    var inputText: String = ""
    var isLoading = false
    private(set) var isMakeupReady = false

    private let chatService: ChatSessionService
    private let agentService: any AIAgentServicing

    init(
        chatService: ChatSessionService = ChatSessionService(),
        agentService: any AIAgentServicing = LocalAIAgentService()
    ) {
        self.chatService = chatService
        self.agentService = agentService
        self.user = UserProfile(
            userId: "mrs_zhang",
            displayName: "Mrs.Zhang",
            status: "开心",
            credits: 50
        )
        reload()
    }

    func reload() {
        do {
            let session = try chatService.loadSession()
            user = session.0
            messages = session.1
            tipText = chatService.cosmeticTip()
        } catch {
            tipText = chatService.cosmeticTip()
        }
    }

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading else { return }
        inputText = ""

        Task {
            isLoading = true
            do {
                _ = try chatService.persistUserText(text, user: user)
                reload()

                let thinking = ChatMessage(
                    sender: .ai,
                    text: "正在理解你的需求并整理妆容建议…",
                    aiAvatarName: "AvatarAI2",
                    kind: .generating
                )
                messages.append(thinking)

                let response = try await agentService.reply(
                    to: AIAgentRequest(
                        userId: user.userId,
                        displayName: user.displayName,
                        message: text
                    )
                )
                _ = try chatService.persistAIResponse(response, user: user)
                reload()
            } catch {
                messages.removeAll { $0.kind == .generating }
            }
            isLoading = false
        }
    }

    func sendSuggestion(_ suggestion: String) {
        inputText = suggestion
        sendMessage()
    }

    func uploadDemoPhoto() {
        perform {
            _ = try chatService.attachDemoPhoto(user: user)
            reload()
        }
    }

    func uploadPhoto(_ image: UIImage) {
        guard !isLoading else { return }
        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                _ = try chatService.attachPhoto(image, user: user)
                reload()
                try await Task.sleep(for: .milliseconds(1100))
                isMakeupReady = true
            } catch {
                // 后续远端 Agent 接入后在此映射上传/生成错误。
            }
        }
    }

    private func perform(_ work: () throws -> Void) {
        isLoading = true
        defer { isLoading = false }
        do {
            try work()
        } catch {
            // Keep UI responsive even if persistence fails.
        }
    }
}
