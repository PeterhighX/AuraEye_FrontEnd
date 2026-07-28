import Foundation
import Observation

@Observable
final class ChatViewModel {
    private(set) var user: UserProfile
    private(set) var messages: [ChatMessage] = []
    private(set) var tipText: String = ""
    var inputText: String = ""
    var isLoading = false

    private let chatService: ChatSessionService

    init(chatService: ChatSessionService = ChatSessionService()) {
        self.chatService = chatService
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
        let text = inputText
        inputText = ""
        perform {
            _ = try chatService.sendUserText(text, user: user)
            reload()
        }
    }

    func sendSuggestion(_ suggestion: String) {
        perform {
            _ = try chatService.sendSuggestion(suggestion, user: user)
            reload()
        }
    }

    func uploadDemoPhoto() {
        perform {
            _ = try chatService.attachDemoPhoto(user: user)
            reload()
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
