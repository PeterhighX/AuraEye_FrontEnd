import Foundation

/// 后续接入大模型或自定义 Agent 时，只需实现此协议并注入 ChatViewModel。
protocol AIAgentServicing {
    func reply(to request: AIAgentRequest) async throws -> AIAgentResponse
}

struct AIAgentRequest: Sendable {
    let userId: String
    let displayName: String
    let message: String
}

struct AIAgentResponse: Sendable {
    let text: String
    let avatarName: String
}

/// 当前前端联调使用的本地实现，延迟用于呈现“AI 思考中”状态。
struct LocalAIAgentService: AIAgentServicing {
    func reply(to request: AIAgentRequest) async throws -> AIAgentResponse {
        try await Task.sleep(for: .milliseconds(900))

        let text: String
        if request.message.contains("图片") || request.message.contains("照片") {
            text = "可以的，请点击相机图标拍摄，或从设备相册选择一张照片，我会结合你的档案进行分析。"
        } else if request.message.contains("清新") {
            text = "明白啦，我会优先选择低饱和、轻透的眼妆配色，并结合你的眼型给出步骤。"
        } else if request.message.contains("正式") {
            text = "好的，我会为你整理更适合正式场合的眼线、眼影和底妆建议。"
        } else {
            text = "收到，\(request.displayName)。我正在结合你的档案和今日场景整理更合适的妆容建议。"
        }

        return AIAgentResponse(text: text, avatarName: "AvatarAI2")
    }
}
