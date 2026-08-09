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

enum APIEndpoint {
    static let healthLive = "/health/live"
    static let login = "/auth/login"
    static let chatMessages = "/chat/messages"
    static let legacyCosmeticsRecognition = "/cosmetics/recognize"
    static let legacyProfileAnalysis = "/profiles/analyze"
    static let makeupGeneration = "/makeup/generate"
    static let makeupRecommendations = "/makeup/recommendations"
    static let mediaUploadIntents = "/media/upload-intents"
    static let profileJobs = "/vision/profile-jobs"
    static let itemRecognitionJobs = "/vision/item-recognition-jobs"

    static func completeMediaAsset(_ assetID: String) -> String {
        "/media/assets/\(assetID)/complete"
    }

    static func visionJob(_ jobID: String) -> String {
        "/vision/jobs/\(jobID)"
    }
}

struct APIConfiguration: Sendable {
    let baseURL: URL
    let accessToken: String?
    let timeout: TimeInterval

    /// 建议由 xcconfig 写入 Info.plist，而不是把正式地址和密钥硬编码进源码。
    static func fromBundle(_ bundle: Bundle = .main) throws -> APIConfiguration {
        let configuredURL = (bundle.object(forInfoDictionaryKey: "AURAEYE_API_BASE_URL") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "API_BASE_URL") as? String)
        guard let configuredURL else {
            throw APIClientError.missingBaseURL
        }
        let normalized = configuredURL.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !normalized.isEmpty,
              let baseURL = URL(string: normalized),
              let scheme = baseURL.scheme?.lowercased(),
              ["https", "http"].contains(scheme),
              baseURL.host != nil else {
            throw APIClientError.missingBaseURL
        }
#if !DEBUG
        guard scheme == "https",
              let host = baseURL.host?.lowercased(),
              host != "localhost",
              host != "127.0.0.1",
              host != "::1" else {
            throw APIClientError.missingBaseURL
        }
#endif

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
    let requestId: String?
    let code: String?
    let message: String?
    let error: NestedAPIErrorPayload?

    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case code, message, error
    }
}

struct NestedAPIErrorPayload: Decodable {
    let code: String?
    let message: String?
}

struct FieldProblem: Decodable, Equatable, Sendable {
    let field: String?
    let path: String?
    let code: String?
    let message: String?
}

struct APIProblem: Decodable, Error, Equatable, Sendable {
    let type: String?
    let title: String
    let status: Int
    let detail: String?
    let instance: String?
    let code: String?
    let requestId: String?
    let retryable: Bool?
    let errors: [FieldProblem]?

    enum CodingKeys: String, CodingKey {
        case type, title, status, detail, instance, code, retryable, errors
        case requestId = "request_id"
    }
}

struct APIResponseMetadata: Equatable, Sendable {
    let serverRequestID: String?
    let location: String?
    let retryAfterSeconds: Int?
}

struct APIResponse<Value> {
    let value: Value
    let metadata: APIResponseMetadata
}

enum APIClientError: LocalizedError {
    case missingBaseURL
    case invalidResponse
    case invalidServerResponse(statusCode: Int, requestID: String?)
    case problem(APIProblem, APIResponseMetadata)
    case httpStatus(Int, String, APIResponseMetadata)
    case invalidImage

    var statusCode: Int? {
        switch self {
        case .invalidServerResponse(let statusCode, _): return statusCode
        case .problem(let problem, _): return problem.status
        case .httpStatus(let status, _, _): return status
        case .missingBaseURL, .invalidResponse, .invalidImage: return nil
        }
    }

    var responseMetadata: APIResponseMetadata? {
        switch self {
        case .problem(_, let metadata), .httpStatus(_, _, let metadata): return metadata
        case .invalidServerResponse(_, let requestID):
            return APIResponseMetadata(serverRequestID: requestID, location: nil, retryAfterSeconds: nil)
        case .missingBaseURL, .invalidResponse, .invalidImage: return nil
        }
    }

    var problemCode: String? {
        switch self {
        case .problem(let problem, _): return problem.code
        default: return nil
        }
    }

    var permitsControlledRetry: Bool {
        switch self {
        case .problem(let problem, let metadata):
            return problem.retryable == true || metadata.retryAfterSeconds != nil
        case .httpStatus(_, _, let metadata):
            return metadata.retryAfterSeconds != nil
        default:
            return false
        }
    }

    var errorDescription: String? {
        switch self {
        case .missingBaseURL:
            return "尚未配置 API_BASE_URL，当前应继续使用本地 Mock 服务。"
        case .invalidResponse:
            return "服务器返回了无法识别的响应。"
        case let .invalidServerResponse(status, requestID):
            return "服务器响应格式异常（\(status)）\(requestIDSuffix(requestID))"
        case let .problem(problem, metadata):
            return "\(problem.detail ?? problem.title)\(requestIDSuffix(metadata.serverRequestID ?? problem.requestId))"
        case let .httpStatus(status, message, metadata):
            return "接口请求失败（\(status)）：\(message)\(requestIDSuffix(metadata.serverRequestID))"
        case .invalidImage:
            return "无法将图片转换为上传数据。"
        }
    }

    private func requestIDSuffix(_ requestID: String?) -> String {
        requestID.map { "（请求编号：\($0)）" } ?? ""
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
        idempotencyKey: String? = nil
    ) async throws -> Response {
        var request = try makeRequest(path: path, method: method, idempotencyKey: idempotencyKey)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return try await perform(request).value
    }

    /// 视觉任务接口的契约当前为直接 JSON，不使用业务 API 的 `data` 包裹。
    /// 为平滑后端包装过程，也兼容被 `data` 包裹的同一 DTO。
    func sendFlexible<Body: Encodable, Response: Decodable>(
        path: String,
        method: HTTPMethod = .post,
        body: Body,
        idempotencyKey: String? = nil
    ) async throws -> Response {
        try await sendFlexibleResponse(
            path: path,
            method: method,
            body: body,
            idempotencyKey: idempotencyKey
        ).value
    }

    func sendFlexibleResponse<Body: Encodable, Response: Decodable>(
        path: String,
        method: HTTPMethod = .post,
        body: Body,
        idempotencyKey: String? = nil
    ) async throws -> APIResponse<Response> {
        var request = try makeRequest(path: path, method: method, idempotencyKey: idempotencyKey)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return try await performFlexible(request)
    }

    func send<Response: Decodable>(
        path: String,
        method: HTTPMethod = .get
    ) async throws -> Response {
        try await perform(makeRequest(path: path, method: method)).value
    }

    func sendFlexible<Response: Decodable>(
        path: String,
        method: HTTPMethod = .get
    ) async throws -> Response {
        try await sendFlexibleResponse(path: path, method: method).value
    }

    func sendFlexibleResponse<Response: Decodable>(
        path: String,
        method: HTTPMethod = .get
    ) async throws -> APIResponse<Response> {
        try await performFlexible(makeRequest(path: path, method: method))
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
                HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode),
                responseMetadata(from: httpResponse)
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
        return try await perform(request).value
    }

    private func makeRequest(
        path: String,
        method: HTTPMethod,
        idempotencyKey: String? = nil
    ) throws -> URLRequest {
        let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard normalizedPath != "v1", !normalizedPath.hasPrefix("v1/") else {
            throw APIClientError.invalidResponse
        }
        let url = configuration.baseURL.appendingPathComponent(normalizedPath)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = configuration.timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let idempotencyKey, !idempotencyKey.isEmpty {
            request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        }
        if let token = configuration.accessToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func perform<Response: Decodable>(_ request: URLRequest) async throws -> APIResponse<Response> {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }
        try validate(httpResponse, data: data)
        guard let envelope = try? decoder.decode(APIEnvelope<Response>.self, from: data) else {
            throw APIClientError.invalidServerResponse(
                statusCode: httpResponse.statusCode,
                requestID: responseMetadata(from: httpResponse).serverRequestID
            )
        }
        let metadata = mergingRequestID(
            responseMetadata(from: httpResponse),
            fallback: envelope.requestId
        )
        return APIResponse(value: envelope.data, metadata: metadata)
    }

    private func performFlexible<Response: Decodable>(_ request: URLRequest) async throws -> APIResponse<Response> {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }
        try validate(httpResponse, data: data)
        let headerMetadata = responseMetadata(from: httpResponse)
        if let envelope = try? decoder.decode(APIEnvelope<Response>.self, from: data) {
            return APIResponse(
                value: envelope.data,
                metadata: mergingRequestID(headerMetadata, fallback: envelope.requestId)
            )
        }
        do {
            return APIResponse(value: try decoder.decode(Response.self, from: data), metadata: headerMetadata)
        } catch {
            throw APIClientError.invalidServerResponse(
                statusCode: httpResponse.statusCode,
                requestID: headerMetadata.serverRequestID
            )
        }
    }

    private func validate(_ response: HTTPURLResponse, data: Data) throws {
        guard !(200..<300).contains(response.statusCode) else { return }
        let metadata = responseMetadata(from: response)
        let contentType = response.value(forHTTPHeaderField: "Content-Type")?
            .lowercased()
            .split(separator: ";", maxSplits: 1)
            .first
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        if contentType == "application/problem+json" {
            guard let problem = try? decoder.decode(APIProblem.self, from: data) else {
                throw APIClientError.invalidServerResponse(
                    statusCode: response.statusCode,
                    requestID: metadata.serverRequestID
                )
            }
            throw APIClientError.problem(problem, metadata)
        }

        if let payload = try? decoder.decode(APIErrorPayload.self, from: data),
           payload.code != nil || payload.message != nil || payload.error != nil {
            throw APIClientError.httpStatus(
                response.statusCode,
                payload.message
                    ?? payload.error?.message
                    ?? HTTPURLResponse.localizedString(forStatusCode: response.statusCode),
                mergingRequestID(metadata, fallback: payload.requestId)
            )
        }
        throw APIClientError.invalidServerResponse(
            statusCode: response.statusCode,
            requestID: metadata.serverRequestID
        )
    }

    private func responseMetadata(from response: HTTPURLResponse) -> APIResponseMetadata {
        APIResponseMetadata(
            serverRequestID: response.value(forHTTPHeaderField: "X-Request-Id"),
            location: response.value(forHTTPHeaderField: "Location"),
            retryAfterSeconds: retryAfterSeconds(response.value(forHTTPHeaderField: "Retry-After"))
        )
    }

    private func mergingRequestID(
        _ metadata: APIResponseMetadata,
        fallback: String?
    ) -> APIResponseMetadata {
        APIResponseMetadata(
            serverRequestID: metadata.serverRequestID ?? fallback,
            location: metadata.location,
            retryAfterSeconds: metadata.retryAfterSeconds
        )
    }

    private func retryAfterSeconds(_ value: String?) -> Int? {
        guard let value else { return nil }
        if let seconds = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return max(seconds, 0)
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss z"
        guard let date = formatter.date(from: value) else { return nil }
        return max(Int(ceil(date.timeIntervalSinceNow)), 0)
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
            path: APIEndpoint.login,
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
            path: APIEndpoint.chatMessages,
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
            path: APIEndpoint.legacyCosmeticsRecognition,
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
            path: APIEndpoint.legacyProfileAnalysis,
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
        try await client.send(path: APIEndpoint.makeupGeneration, body: context)
    }
}

final class RemoteMakeupRecommendationService: MakeupRecommendationServicing {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func recommendations(context: MakeupGenerationContext) async throws -> [GeneratedMakeupPlan] {
        try await client.send(path: APIEndpoint.makeupRecommendations, body: context)
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
