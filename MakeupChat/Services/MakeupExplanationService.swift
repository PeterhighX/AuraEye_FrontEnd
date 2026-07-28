import Foundation

/// 后续接入大模型讲解时，实现此协议并替换本地实现。
protocol MakeupExplanationServicing {
    func explain(stepTitle: String, instruction: String) async throws -> String
}

struct LocalMakeupExplanationService: MakeupExplanationServicing {
    func explain(stepTitle: String, instruction: String) async throws -> String {
        try await Task.sleep(for: .milliseconds(650))
        return "讲解：\(stepTitle)时请少量取粉，从边缘向中心轻轻晕染。先完成一侧再对照另一侧，避免一次下手过重。"
    }
}
