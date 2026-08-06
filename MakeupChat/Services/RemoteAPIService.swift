import Foundation
import UIKit

// MARK: - Shared HTTP client

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

struct APIConfiguration: Sendable {
    let baseURL: URL
    let accessToken: String?
    let timeout: TimeInterval

    /// 建议由 xcconfig 写入 Info.plist，而不是把正式地址和密钥硬编码进源码。
    static func fromBundle(_ bundle: Bundle = .main) throws -> APIConfiguration {
        guard
            let rawURL = bundle.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
            let baseURL = URL(string: rawURL),
            !rawURL.isEmpty
        else {
            throw APIClientError.missingBaseURL
        }

        return APIConfiguration(
            baseURL: baseURL,
            accessToken: bundle.object(forInfoDictionaryKey: "API_ACCESS_TOKEN") as? String,
            timeout: 45
        )
    }
}

struct APIEnvelope<Value: Decodable>: Decodable {
    let requestId: String?
    let data: Value

    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case data
    }
}

struct APIErrorPayload: Decodable {
    let code: String?
    let message: String?
    let error: NestedAPIErrorPayload?
}

struct NestedAPIErrorPayload: Decodable {
    let code: String?
    let message: String?
}

enum APIClientError: LocalizedError {
    case missingBaseURL
    case invalidResponse
    case httpStatus(Int, String)
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .missingBaseURL:
            return "尚未配置 API_BASE_URL，当前应继续使用本地 Mock 服务。"
        case .invalidResponse:
            return "服务器返回了无法识别的响应。"
        case let .httpStatus(status, message):
            return "接口请求失败（\(status)）：\(message)"
        case .invalidImage:
            return "无法将图片转换为上传数据。"
        }
    }
}

actor APIClient {
    private let configuration: APIConfiguration
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        configuration: APIConfiguration,
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.session = session
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func send<Body: Encodable, Response: Decodable>(
        path: String,
        method: HTTPMethod = .post,
        body: Body,
        requestID: String? = nil
    ) async throws -> Response {
        var request = try makeRequest(path: path, method: method, requestID: requestID)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return try await perform(request)
    }

    /// 视觉任务接口的契约当前为直接 JSON，不使用业务 API 的 `data` 包裹。
    /// 为平滑后端包装过程，也兼容被 `data` 包裹的同一 DTO。
    func sendFlexible<Body: Encodable, Response: Decodable>(
        path: String,
        method: HTTPMethod = .post,
        body: Body,
        requestID: String? = nil
    ) async throws -> Response {
        var request = try makeRequest(path: path, method: method, requestID: requestID)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return try await performFlexible(request)
    }

    func send<Response: Decodable>(
        path: String,
        method: HTTPMethod = .get,
        requestID: String? = nil
    ) async throws -> Response {
        try await perform(makeRequest(path: path, method: method, requestID: requestID))
    }

    func sendFlexible<Response: Decodable>(
        path: String,
        method: HTTPMethod = .get,
        requestID: String? = nil
    ) async throws -> Response {
        try await performFlexible(makeRequest(path: path, method: method, requestID: requestID))
    }

    /// 对象存储直传不携带 AuraEye Bearer Token，只使用上传意图返回的请求头。
    func uploadBinary(
        to url: URL,
        method: String,
        headers: [String: String],
        data: Data
    ) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = configuration.timeout
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        request.httpBody = data

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIClientError.httpStatus(
                httpResponse.statusCode,
                HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            )
        }
    }

    func uploadImage<Response: Decodable>(
        path: String,
        image: UIImage,
        fields: [String: String]
    ) async throws -> Response {
        guard let imageData = image.jpegData(compressionQuality: 0.88) else {
            throw APIClientError.invalidImage
        }

        let boundary = "AuraAye-\(UUID().uuidString)"
        var request = try makeRequest(path: path, method: .post)
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )
        request.httpBody = multipartBody(
            boundary: boundary,
            fields: fields,
            imageData: imageData
        )
        return try await perform(request)
    }

    private func makeRequest(
        path: String,
        method: HTTPMethod,
        requestID: String? = nil
    ) throws -> URLRequest {
        let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let url = configuration.baseURL.appendingPathComponent(normalizedPath)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = configuration.timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(requestID ?? UUID().uuidString, forHTTPHeaderField: "X-Request-ID")
        if let token = configuration.accessToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func perform<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let payload = try? decoder.decode(APIErrorPayload.self, from: data)
            throw APIClientError.httpStatus(
                httpResponse.statusCode,
                payload?.message
                    ?? payload?.error?.message
                    ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            )
        }

        return try decoder.decode(APIEnvelope<Response>.self, from: data).data
    }

    private func performFlexible<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let payload = try? decoder.decode(APIErrorPayload.self, from: data)
            throw APIClientError.httpStatus(
                httpResponse.statusCode,
                payload?.message
                    ?? payload?.error?.message
                    ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            )
        }
        if let envelope = try? decoder.decode(APIEnvelope<Response>.self, from: data) {
            return envelope.data
        }
        return try decoder.decode(Response.self, from: data)
    }

    private func multipartBody(
        boundary: String,
        fields: [String: String],
        imageData: Data
    ) -> Data {
        var data = Data()
        let lineBreak = "\r\n"

        for (key, value) in fields {
            data.append("--\(boundary)\(lineBreak)")
            data.append("Content-Disposition: form-data; name=\"\(key)\"\(lineBreak)\(lineBreak)")
            data.append("\(value)\(lineBreak)")
        }

        data.append("--\(boundary)\(lineBreak)")
        data.append("Content-Disposition: form-data; name=\"image\"; filename=\"upload.jpg\"\(lineBreak)")
        data.append("Content-Type: image/jpeg\(lineBreak)\(lineBreak)")
        data.append(imageData)
        data.append(lineBreak)
        data.append("--\(boundary)--\(lineBreak)")
        return data
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}

// MARK: - 1. Negative-one-screen chat

final class RemoteAuthenticationService: AuthenticationServicing {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func login(account: String, password: String) async throws -> AuthenticatedAccount {
        try await client.send(
            path: "/v1/auth/login",
            body: LoginRequest(account: account, password: password)
        )
    }
}

// MARK: - 1. Negative-one-screen chat

private struct RemoteChatRequest: Encodable {
    let userId: String
    let displayName: String
    let message: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case displayName = "display_name"
        case message
    }
}

private struct RemoteChatResponse: Decodable {
    let message: String
    let avatarAsset: String?

    enum CodingKeys: String, CodingKey {
        case message
        case avatarAsset = "avatar_asset"
    }
}

final class RemoteAIAgentService: AIAgentServicing {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func reply(to request: AIAgentRequest) async throws -> AIAgentResponse {
        let response: RemoteChatResponse = try await client.send(
            path: "/v1/chat/messages",
            body: RemoteChatRequest(
                userId: request.userId,
                displayName: request.displayName,
                message: request.message
            )
        )
        return AIAgentResponse(
            text: response.message,
            avatarName: response.avatarAsset ?? "AvatarAI2"
        )
    }
}

// MARK: - 2. Cosmetics recognition

private struct RemoteCosmeticResponse: Decodable {
    let displayName: String
    let category: String
    let tags: [String]
    let colorHexes: [String]
    let material: String
    let summary: String

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case category, tags
        case colorHexes = "color_hexes"
        case material, summary
    }
}

final class RemoteCosmeticsRecognitionService: CosmeticsRecognitionServicing {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func recognize(image: UIImage, categoryHint: String?) async throws -> CosmeticsRecognitionResult {
        var fields: [String: String] = [:]
        if let categoryHint, !categoryHint.isEmpty {
            fields["category_hint"] = categoryHint
        }

        let response: RemoteCosmeticResponse = try await client.uploadImage(
            path: "/v1/cosmetics/recognize",
            image: image,
            fields: fields
        )
        let previewPath = try LocalMediaStore.saveImage(
            image,
            bucket: .cosmetics,
            fileName: "cosmetic_\(UUID().uuidString.lowercased()).jpg"
        )

        return CosmeticsRecognitionResult(
            displayName: response.displayName,
            category: response.category,
            tags: response.tags,
            colorHexes: response.colorHexes,
            material: response.material,
            summary: response.summary,
            previewPath: previewPath
        )
    }
}

// MARK: - 3. User profile creation / face analysis

private struct RemoteFaceAnalysisResponse: Decodable {
    let avatarBase64: String?
    let profile: [String: String]

    enum CodingKeys: String, CodingKey {
        case avatarBase64 = "avatar_base64"
        case profile
    }
}

final class RemoteFaceAnalysisService: FaceAnalysisServicing {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func analyze(image: UIImage, userId: String) async throws -> FaceAnalysisResult {
        let response: RemoteFaceAnalysisResponse = try await client.uploadImage(
            path: "/v1/profiles/analyze",
            image: image,
            fields: ["user_id": userId]
        )

        let avatar = response.avatarBase64
            .flatMap { Data(base64Encoded: $0) }
            .flatMap { UIImage(data: $0) }
            ?? image
        let portraitPath = try LocalMediaStore.savePNGImage(
            avatar,
            bucket: .portraits,
            fileName: "virtual_avatar_\(userId).png"
        )
        let profileData = try JSONEncoder().encode(response.profile)

        return FaceAnalysisResult(
            portraitPath: portraitPath,
            profileJSON: String(decoding: profileData, as: UTF8.self)
        )
    }
}

// MARK: - 4/5. Makeup generation and recommendations

struct MakeupGenerationContext: Encodable, Sendable {
    let userId: String
    let profileJSON: String?
    let cosmeticCategories: [String]
    let scene: String
    let weather: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case profileJSON = "profile"
        case cosmeticCategories = "cosmetic_categories"
        case scene, weather
    }
}

struct GeneratedMakeupStep: Codable, Identifiable, Sendable {
    let id: Int
    let title: String
    let tool: String
    let instruction: String
    let tip: String
    let previewAsset: String?

    enum CodingKeys: String, CodingKey {
        case id, title, tool, instruction, tip
        case previewAsset = "preview_asset"
    }
}

struct GeneratedMakeupPlan: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let tag: String
    let summary: String
    let imageURL: String?
    let colorHexes: [String]
    let steps: [GeneratedMakeupStep]

    enum CodingKeys: String, CodingKey {
        case id, title, tag, summary, steps
        case imageURL = "image_url"
        case colorHexes = "color_hexes"
    }
}

protocol MakeupGenerationServicing {
    func generate(context: MakeupGenerationContext) async throws -> GeneratedMakeupPlan
}

protocol MakeupRecommendationServicing {
    func recommendations(context: MakeupGenerationContext) async throws -> [GeneratedMakeupPlan]
}

final class RemoteMakeupGenerationService: MakeupGenerationServicing {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func generate(context: MakeupGenerationContext) async throws -> GeneratedMakeupPlan {
        try await client.send(path: "/v1/makeup/generate", body: context)
    }
}

final class RemoteMakeupRecommendationService: MakeupRecommendationServicing {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func recommendations(context: MakeupGenerationContext) async throws -> [GeneratedMakeupPlan] {
        try await client.send(path: "/v1/makeup/recommendations", body: context)
    }
}

/// 统一创建远端服务，便于在 App 根节点或依赖容器中集中切换。
struct RemoteServiceContainer {
    let client: APIClient
    let authentication: RemoteAuthenticationService
    let chat: RemoteAIAgentService
    let cosmetics: RemoteCosmeticsRecognitionService
    let faceAnalysis: RemoteFaceAnalysisService
    let makeupGeneration: RemoteMakeupGenerationService
    let makeupRecommendation: RemoteMakeupRecommendationService

    init(configuration: APIConfiguration) {
        let client = APIClient(configuration: configuration)
        self.client = client
        self.authentication = RemoteAuthenticationService(client: client)
        self.chat = RemoteAIAgentService(client: client)
        self.cosmetics = RemoteCosmeticsRecognitionService(client: client)
        self.faceAnalysis = RemoteFaceAnalysisService(client: client)
        self.makeupGeneration = RemoteMakeupGenerationService(client: client)
        self.makeupRecommendation = RemoteMakeupRecommendationService(client: client)
    }
}
