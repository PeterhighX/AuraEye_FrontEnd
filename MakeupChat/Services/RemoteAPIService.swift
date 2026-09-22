import Foundation
import OSLog

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
    static let refresh = "/auth/refresh"
    static let logout = "/auth/logout"
    static let authMe = "/auth/me"
    static let chatMessages = "/chat/messages"
    static let makeupGeneration = "/makeup/generate"
    static let makeupRecommendations = "/makeup/recommendations"
    static let visionJobs = "/vision/jobs"

    static func visionJob(_ jobID: String) -> String {
        "/vision/jobs/\(jobID)"
    }

    static func visionJobResultImage(_ jobID: String) -> String {
        "/vision/jobs/\(jobID)/result-image"
    }
}

enum APIConfigurationError: LocalizedError, Equatable, Sendable {
    case configurationMissing
    case configurationInvalid(String)

    var errorDescription: String? {
        switch self {
        case .configurationMissing:
            return "当前 App 未配置 AuraEye API 地址，请检查构建配置。"
        case .configurationInvalid:
            return "当前 App 的 AuraEye API 地址无效，请检查构建配置。"
        }
    }
}

struct APIConfiguration: Equatable, Sendable {
    let baseURL: URL
    let accessToken: String?
    let timeout: TimeInterval

    static func loadBaseURL(bundle: Bundle = .main) throws -> URL {
        try loadBaseURL(
            rawValue: bundle.object(forInfoDictionaryKey: "AURAEYE_API_BASE_URL") as? String
        )
    }

    static func loadBaseURL(rawValue: String?) throws -> URL {
        guard let rawValue else {
            throw APIConfigurationError.configurationMissing
        }
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
              !value.contains("$("),
              let url = URL(string: value),
              url.scheme?.lowercased() == "https",
              url.host != nil,
              url.query == nil,
              url.fragment == nil else {
            throw APIConfigurationError.configurationInvalid(value)
        }
        return url
    }

    /// 从最终 App Bundle 的 Info.plist 读取并校验一次构建期注入值。
    static func fromBundle(_ bundle: Bundle = .main) throws -> APIConfiguration {
        let baseURL = try loadBaseURL(bundle: bundle)

        return APIConfiguration(
            baseURL: baseURL,
            accessToken: nil,
            timeout: 45
        )
    }
}

/// App 生命周期内唯一的远端配置入口。登录与视觉服务共享同一份已校验配置。
@MainActor
final class APIEnvironment {
    static let shared = APIEnvironment()

    private(set) var configuration: APIConfiguration?

    private init() {}

    func load(bundle: Bundle = .main) throws -> APIConfiguration {
        if let configuration { return configuration }
        let loaded = try APIConfiguration.fromBundle(bundle)
        configuration = loaded
        return loaded
    }

    func install(_ configuration: APIConfiguration) {
        self.configuration = configuration
    }

    func authenticatedClient(accessToken: String) throws -> APIClient {
        guard let configuration else {
            throw APIConfigurationError.configurationMissing
        }
        return APIClient(configuration: APIConfiguration(
            baseURL: configuration.baseURL,
            accessToken: accessToken,
            timeout: configuration.timeout
        ))
    }

#if DEBUG
    func resetForTesting() {
        configuration = nil
    }
#endif
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

struct APIBinaryResponse {
    let data: Data
    let contentType: String?
    let metadata: APIResponseMetadata
}

struct ServerSentEvent: Sendable, Equatable {
    let id: String?
    let name: String?
    let data: String
}

enum APIClientError: LocalizedError {
    case networkUnavailable
    case invalidResponse
    case invalidServerResponse(statusCode: Int, requestID: String?)
    case problem(APIProblem, APIResponseMetadata)
    case httpStatus(Int, String, code: String?, APIResponseMetadata)
    case invalidImage

    var statusCode: Int? {
        switch self {
        case .invalidServerResponse(let statusCode, _): return statusCode
        case .problem(let problem, _): return problem.status
        case .httpStatus(let status, _, _, _): return status
        case .networkUnavailable, .invalidResponse, .invalidImage: return nil
        }
    }

    var responseMetadata: APIResponseMetadata? {
        switch self {
        case .problem(_, let metadata), .httpStatus(_, _, _, let metadata): return metadata
        case .invalidServerResponse(_, let requestID):
            return APIResponseMetadata(serverRequestID: requestID, location: nil, retryAfterSeconds: nil)
        case .networkUnavailable, .invalidResponse, .invalidImage: return nil
        }
    }

    var problemCode: String? {
        switch self {
        case .problem(let problem, _): return problem.code
        case .httpStatus(_, _, let code, _): return code
        default: return nil
        }
    }

    var diagnosticRequestID: String? {
        switch self {
        case .problem(let problem, let metadata):
            return metadata.serverRequestID ?? problem.requestId
        case .httpStatus(_, _, _, let metadata):
            return metadata.serverRequestID
        case .invalidServerResponse(_, let requestID):
            return requestID
        case .networkUnavailable, .invalidResponse, .invalidImage:
            return nil
        }
    }

    var permitsControlledRetry: Bool {
        switch self {
        case .problem(let problem, let metadata):
            return problem.retryable == true || metadata.retryAfterSeconds != nil
        case .httpStatus(_, _, _, let metadata):
            return metadata.retryAfterSeconds != nil
        default:
            return false
        }
    }

    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "网络不可用，请检查连接后重试。"
        case .invalidResponse:
            return "服务器返回了无法识别的响应。"
        case let .invalidServerResponse(status, requestID):
            return "服务器响应格式异常（\(status)）\(requestIDSuffix(requestID))"
        case let .problem(problem, metadata):
            return "\(problem.detail ?? problem.title)\(requestIDSuffix(metadata.serverRequestID ?? problem.requestId))"
        case let .httpStatus(status, message, _, metadata):
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
    private static let authorizationRefreshCoordinator = AuthorizationRefreshCoordinator()
    private static let transportLogger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.makeup.chat",
        category: "APITransport"
    )
    private let configuration: APIConfiguration
    private let session: URLSession
    private let dataLoader: @Sendable (URLRequest) async throws -> (Data, URLResponse)
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        configuration: APIConfiguration,
        session: URLSession = .shared,
        dataLoader: (@Sendable (URLRequest) async throws -> (Data, URLResponse))? = nil
    ) {
        self.configuration = configuration
        self.session = session
        self.dataLoader = dataLoader ?? { request in
            try await session.data(for: request)
        }
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func configuredBaseURL() -> URL {
        configuration.baseURL
    }

    func authenticated(with accessToken: String) -> APIClient {
        APIClient(
            configuration: APIConfiguration(
                baseURL: configuration.baseURL,
                accessToken: accessToken,
                timeout: configuration.timeout
            ),
            session: session,
            dataLoader: dataLoader
        )
    }

    func send<Body: Encodable, Response: Decodable>(
        path: String,
        method: HTTPMethod = .post,
        body: Body,
        idempotencyKey: String? = nil,
        expectedStatusCode: Int? = nil
    ) async throws -> Response {
        var request = try makeRequest(path: path, method: method, idempotencyKey: idempotencyKey)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return try await perform(request, expectedStatusCode: expectedStatusCode).value
    }

    func send<Response: Decodable>(
        path: String,
        method: HTTPMethod = .get,
        expectedStatusCode: Int? = nil
    ) async throws -> Response {
        try await perform(
            makeRequest(path: path, method: method),
            expectedStatusCode: expectedStatusCode
        ).value
    }

    func sendResponse<Response: Decodable>(
        path: String,
        method: HTTPMethod = .get,
        expectedStatusCode: Int? = nil
    ) async throws -> APIResponse<Response> {
        try await perform(
            makeRequest(path: path, method: method),
            expectedStatusCode: expectedStatusCode
        )
    }

    func sendResponse<Body: Encodable, Response: Decodable>(
        path: String,
        method: HTTPMethod = .post,
        body: Body,
        idempotencyKey: String? = nil,
        expectedStatusCode: Int? = nil
    ) async throws -> APIResponse<Response> {
        var request = try makeRequest(path: path, method: method, idempotencyKey: idempotencyKey)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return try await perform(request, expectedStatusCode: expectedStatusCode)
    }

    func eventStream<Body: Encodable>(
        path: String,
        body: Body,
        idempotencyKey: String? = nil
    ) throws -> AsyncThrowingStream<ServerSentEvent, Error> {
        var request = try makeRequest(path: path, method: .post, idempotencyKey: idempotencyKey)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.httpBody = try encoder.encode(body)

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await self.consumeEventStream(request, continuation: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: self.normalizedStreamError(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func sendMultipartResponse<Response: Decodable>(
        path: String,
        fields: [String: String],
        imageData: Data,
        imageContentType: String,
        idempotencyKey: String,
        expectedStatusCode: Int? = nil
    ) async throws -> APIResponse<Response> {
        guard imageContentType.lowercased().hasPrefix("image/") else {
            throw VisionAPIError.unsupportedMediaType
        }

        let boundary = "AuraEye-\(UUID().uuidString)"
        var request = try makeRequest(
            path: path,
            method: .post,
            idempotencyKey: idempotencyKey
        )
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )
        request.httpBody = multipartBody(
            boundary: boundary,
            fields: fields,
            imageData: imageData,
            imageContentType: imageContentType
        )
        return try await perform(request, expectedStatusCode: expectedStatusCode)
    }

    func downloadResponse(
        path: String,
        expectedContentType: String
    ) async throws -> APIBinaryResponse {
        let request = try makeRequest(path: path, method: .get)
        return try await downloadResponse(
            request: request,
            expectedContentType: expectedContentType,
            permitsAuthorizationRefresh: true
        )
    }

    private func downloadResponse(
        request: URLRequest,
        expectedContentType: String,
        permitsAuthorizationRefresh: Bool
    ) async throws -> APIBinaryResponse {
        do {
            return try await downloadResponseOnce(request: request, expectedContentType: expectedContentType)
        } catch let error as APIClientError where permitsAuthorizationRefresh
            && error.statusCode == 401
            && request.value(forHTTPHeaderField: "Authorization")?.hasPrefix("Bearer ") == true {
            let retry = try await requestWithRefreshedAuthorization(from: request)
            return try await downloadResponse(
                request: retry,
                expectedContentType: expectedContentType,
                permitsAuthorizationRefresh: false
            )
        }
    }

    private func downloadResponseOnce(
        request initialRequest: URLRequest,
        expectedContentType: String
    ) async throws -> APIBinaryResponse {
        var request = initialRequest
        request.setValue(expectedContentType, forHTTPHeaderField: "Accept")
        let (data, response) = try await loadData(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }
        try validate(httpResponse, data: data, expectedStatusCode: 200)
        let contentType = normalizedContentType(httpResponse.value(forHTTPHeaderField: "Content-Type"))
        guard contentType == expectedContentType else {
            throw APIClientError.invalidServerResponse(
                statusCode: httpResponse.statusCode,
                requestID: responseMetadata(from: httpResponse).serverRequestID
            )
        }
        return APIBinaryResponse(
            data: data,
            contentType: contentType,
            metadata: responseMetadata(from: httpResponse)
        )
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

    private func perform<Response: Decodable>(
        _ request: URLRequest,
        expectedStatusCode: Int?
    ) async throws -> APIResponse<Response> {
        try await perform(
            request,
            expectedStatusCode: expectedStatusCode,
            permitsAuthorizationRefresh: true
        )
    }

    private func perform<Response: Decodable>(
        _ request: URLRequest,
        expectedStatusCode: Int?,
        permitsAuthorizationRefresh: Bool
    ) async throws -> APIResponse<Response> {
        do {
            return try await performOnce(request, expectedStatusCode: expectedStatusCode)
        } catch let error as APIClientError where permitsAuthorizationRefresh
            && error.statusCode == 401
            && request.value(forHTTPHeaderField: "Authorization")?.hasPrefix("Bearer ") == true {
            let retry = try await requestWithRefreshedAuthorization(from: request)
            return try await perform(
                retry,
                expectedStatusCode: expectedStatusCode,
                permitsAuthorizationRefresh: false
            )
        }
    }

    private func performOnce<Response: Decodable>(
        _ request: URLRequest,
        expectedStatusCode: Int?
    ) async throws -> APIResponse<Response> {
        let (data, response) = try await loadData(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }
        try validate(httpResponse, data: data, expectedStatusCode: expectedStatusCode)
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

    private func consumeEventStream(
        _ initialRequest: URLRequest,
        continuation: AsyncThrowingStream<ServerSentEvent, Error>.Continuation
    ) async throws {
        var request = initialRequest
        var permitsAuthorizationRefresh = true

        while true {
            let (bytes, response) = try await session.bytes(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIClientError.invalidResponse
            }

            if httpResponse.statusCode == 401,
               permitsAuthorizationRefresh,
               request.value(forHTTPHeaderField: "Authorization")?.hasPrefix("Bearer ") == true {
                permitsAuthorizationRefresh = false
                request = try await requestWithRefreshedAuthorization(from: request)
                continue
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                var data = Data()
                for try await byte in bytes { data.append(byte) }
                try validate(httpResponse, data: data, expectedStatusCode: nil)
                throw APIClientError.invalidServerResponse(
                    statusCode: httpResponse.statusCode,
                    requestID: responseMetadata(from: httpResponse).serverRequestID
                )
            }

            guard normalizedContentType(httpResponse.value(forHTTPHeaderField: "Content-Type")) == "text/event-stream" else {
                throw APIClientError.invalidServerResponse(
                    statusCode: httpResponse.statusCode,
                    requestID: responseMetadata(from: httpResponse).serverRequestID
                )
            }

            var eventID: String?
            var eventName: String?
            var dataLines: [String] = []

            func emit() {
                guard !dataLines.isEmpty else {
                    eventID = nil
                    eventName = nil
                    return
                }
                continuation.yield(ServerSentEvent(
                    id: eventID,
                    name: eventName,
                    data: dataLines.joined(separator: "\n")
                ))
                eventID = nil
                eventName = nil
                dataLines.removeAll(keepingCapacity: true)
            }

            for try await line in bytes.lines {
                try Task.checkCancellation()
                if line.isEmpty {
                    emit()
                    continue
                }
                if line.hasPrefix(":") { continue }

                let pieces = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
                let field = String(pieces[0])
                var value = pieces.count == 2 ? String(pieces[1]) : ""
                if value.hasPrefix(" ") { value.removeFirst() }
                switch field {
                case "id": eventID = value
                case "event": eventName = value
                case "data": dataLines.append(value)
                default: break
                }
            }
            emit()
            return
        }
    }

    private func normalizedStreamError(_ error: Error) -> Error {
        if error is CancellationError { return CancellationError() }
        if let error = error as? URLError {
            return error.code == .cancelled ? CancellationError() : APIClientError.networkUnavailable
        }
        return error
    }

    private func requestWithRefreshedAuthorization(from request: URLRequest) async throws -> URLRequest {
        guard let authorization = request.value(forHTTPHeaderField: "Authorization"),
              authorization.hasPrefix("Bearer ") else {
            throw APIClientError.invalidServerResponse(statusCode: 401, requestID: nil)
        }
        let rejectedToken = String(authorization.dropFirst("Bearer ".count))
        let context = await MainActor.run { SessionManager.shared.context }
        guard let context, let refreshToken = context.refreshToken, !refreshToken.isEmpty else {
            await MainActor.run { SessionManager.shared.clear() }
            throw APIClientError.invalidServerResponse(statusCode: 401, requestID: nil)
        }

        let refreshed: AuthenticatedAccount
        if context.accessToken != rejectedToken {
            refreshed = try await MainActor.run {
                guard let account = SessionManager.shared.context else {
                    throw APIClientError.invalidServerResponse(statusCode: 401, requestID: nil)
                }
                return AuthenticatedAccount(
                    userId: account.userId,
                    username: account.username,
                    displayName: account.displayName,
                    accessToken: account.accessToken,
                    refreshToken: account.refreshToken,
                    expiresAt: nil,
                    accountMode: account.accountMode,
                    features: account.features
                )
            }
        } else {
            do {
                refreshed = try await Self.authorizationRefreshCoordinator.refresh { [self] in
                    try await self.refreshSession(refreshToken: refreshToken)
                }
                await MainActor.run { SessionManager.shared.establish(account: refreshed) }
            } catch {
                await MainActor.run { SessionManager.shared.clear() }
                throw error
            }
        }

        var retry = request
        retry.setValue("Bearer \(refreshed.accessToken)", forHTTPHeaderField: "Authorization")
        return retry
    }

    private func refreshSession(refreshToken: String) async throws -> AuthenticatedAccount {
        var request = try makeRequest(path: APIEndpoint.refresh, method: .post)
        request.setValue(nil, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(RefreshTokenRequest(refreshToken: refreshToken))

        let (data, response) = try await loadData(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }
        try validate(httpResponse, data: data, expectedStatusCode: 200)
        guard let envelope = try? decoder.decode(APIEnvelope<AuthenticatedAccount>.self, from: data) else {
            throw APIClientError.invalidServerResponse(
                statusCode: httpResponse.statusCode,
                requestID: responseMetadata(from: httpResponse).serverRequestID
            )
        }
        return envelope.data
    }

    private func loadData(for request: URLRequest) async throws -> (Data, URLResponse) {
        let endpoint = request.url?.path ?? "unknown"
        do {
            return try await dataLoader(request)
        } catch is CancellationError {
            Self.transportLogger.debug(
                "API transport cancelled stage=load endpoint=\(endpoint, privacy: .public) code=swift_cancellation task_cancelled=\(Task.isCancelled, privacy: .public)"
            )
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            Self.transportLogger.debug(
                "API transport cancelled stage=load endpoint=\(endpoint, privacy: .public) code=\(error.code.rawValue, privacy: .public) task_cancelled=\(Task.isCancelled, privacy: .public)"
            )
            throw CancellationError()
        } catch let error as URLError {
            Self.transportLogger.error(
                "API transport failed stage=load endpoint=\(endpoint, privacy: .public) code=\(error.code.rawValue, privacy: .public) task_cancelled=\(Task.isCancelled, privacy: .public)"
            )
            throw APIClientError.networkUnavailable
        }
    }

    private func validate(
        _ response: HTTPURLResponse,
        data: Data,
        expectedStatusCode: Int?
    ) throws {
        if let expectedStatusCode {
            if response.statusCode == expectedStatusCode { return }
        } else if (200..<300).contains(response.statusCode) {
            return
        }
        let metadata = responseMetadata(from: response)

        if (200..<300).contains(response.statusCode) {
            throw APIClientError.invalidServerResponse(
                statusCode: response.statusCode,
                requestID: metadata.serverRequestID
            )
        }
        let contentType = normalizedContentType(response.value(forHTTPHeaderField: "Content-Type"))

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
                code: payload.code ?? payload.error?.code,
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

    private func normalizedContentType(_ value: String?) -> String? {
        value?
            .lowercased()
            .split(separator: ";", maxSplits: 1)
            .first
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
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
        imageData: Data,
        imageContentType: String = "image/jpeg"
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
        data.append("Content-Type: \(imageContentType)\(lineBreak)\(lineBreak)")
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
        let authenticated: AuthenticatedAccount = try await client.send(
            path: APIEndpoint.login,
            body: LoginRequest(username: account, password: password),
            expectedStatusCode: 200
        )
        let authenticatedClient = await client.authenticated(with: authenticated.accessToken)
        let me: APIResponse<AuthMeFeatureDTO> = try await authenticatedClient.sendResponse(
            path: APIEndpoint.authMe,
            method: .get,
            expectedStatusCode: 200
        )
        return authenticated.applyingServerFeatures(me.value.features)
    }

    func refresh(refreshToken: String) async throws -> AuthenticatedAccount {
        try await client.send(
            path: APIEndpoint.refresh,
            body: RefreshTokenRequest(refreshToken: refreshToken),
            expectedStatusCode: 200
        )
    }

    func logout(accessToken: String, refreshToken: String) async throws {
        let authenticatedClient = await client.authenticated(with: accessToken)
        let response: LogoutResponseDTO = try await authenticatedClient.send(
            path: APIEndpoint.logout,
            body: LogoutRequest(refreshToken: refreshToken),
            expectedStatusCode: 200
        )
        guard response.revoked else {
            throw APIClientError.invalidResponse
        }
    }
}

private actor AuthorizationRefreshCoordinator {
    private var activeRefresh: Task<AuthenticatedAccount, Error>?

    func refresh(
        operation: @escaping @Sendable () async throws -> AuthenticatedAccount
    ) async throws -> AuthenticatedAccount {
        if let activeRefresh {
            return try await activeRefresh.value
        }
        let task = Task { try await operation() }
        activeRefresh = task
        defer { activeRefresh = nil }
        return try await task.value
    }
}

// MARK: - 1. Negative-one-screen chat

private struct RemoteChatStreamPayload: Decodable {
    let type: String?
    let requestId: String?
    let conversationId: String?
    let messageId: String?
    let delta: String?
    let message: String?
    let code: String?
    let detail: String?
    let retryable: Bool?
    let serverRequestId: String?
    let httpStatus: Int?
    let toolCallId: String?
    let name: String?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case type
        case requestId = "request_id"
        case conversationId = "conversation_id"
        case messageId = "message_id"
        case delta, message, code, detail, retryable, name, status
        case serverRequestId = "server_request_id"
        case httpStatus = "http_status"
        case toolCallId = "tool_call_id"
    }
}

final class RemoteAIAgentService: AIAgentServicing, @unchecked Sendable {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func stream(_ request: ChatSendRequest) -> AsyncThrowingStream<ChatStreamEvent, Error> {
        do {
            try validate(request)
        } catch {
            return AsyncThrowingStream { $0.finish(throwing: error) }
        }

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let events = try await client.eventStream(
                        path: APIEndpoint.chatMessages,
                        body: request,
                        idempotencyKey: request.requestId
                    )
                    let decoder = JSONDecoder()

                    for try await event in events {
                        guard let data = event.data.data(using: .utf8),
                              let payload = try? decoder.decode(RemoteChatStreamPayload.self, from: data) else {
                            throw ChatContractError.invalidResponse
                        }
                        try validateIdentity(payload, request: request)
                        if let eventType = event.name,
                           let payloadType = payload.type,
                           eventType != payloadType {
                            throw ChatContractError.invalidResponse
                        }
                        let type = event.name ?? payload.type
                        switch type {
                        case "message.accepted":
                            guard let messageId = payload.messageId, !messageId.isEmpty else {
                                throw ChatContractError.invalidResponse
                            }
                            continuation.yield(.accepted(messageId: messageId))
                        case "assistant.started":
                            guard let messageId = payload.messageId, !messageId.isEmpty else {
                                throw ChatContractError.invalidResponse
                            }
                            continuation.yield(.assistantStarted(messageId: messageId))
                        case "assistant.delta":
                            if let delta = payload.delta, !delta.isEmpty {
                                continuation.yield(.assistantDelta(delta))
                            }
                        case "tool.started":
                            guard let id = payload.toolCallId, let name = payload.name else {
                                throw ChatContractError.invalidResponse
                            }
                            continuation.yield(.toolStarted(id: id, name: name))
                        case "tool.completed":
                            guard let id = payload.toolCallId, let name = payload.name else {
                                throw ChatContractError.invalidResponse
                            }
                            continuation.yield(.toolCompleted(id: id, name: name, status: payload.status ?? "completed"))
                        case "message.completed":
                            guard let messageId = payload.messageId,
                                  let message = payload.message?.trimmingCharacters(in: .whitespacesAndNewlines),
                                  !messageId.isEmpty, !message.isEmpty else {
                                throw ChatContractError.invalidResponse
                            }
                            continuation.yield(.completed(ChatReply(
                                clientRequestId: request.requestId,
                                conversationId: request.conversationId,
                                messageId: messageId,
                                message: message,
                                avatarAsset: "AvatarAI2",
                                status: "completed",
                                serverRequestId: payload.serverRequestId
                            )))
                            continuation.finish()
                            return
                        case "error":
                            continuation.yield(.failed(ChatStreamFailure(
                                code: payload.code ?? "CHAT_STREAM_FAILED",
                                detail: payload.detail ?? "对话生成失败。",
                                retryable: payload.retryable ?? false,
                                serverRequestId: payload.serverRequestId,
                                httpStatus: payload.httpStatus
                            )))
                            continuation.finish()
                            return
                        default:
                            continue
                        }
                    }

                    throw ChatContractError.invalidResponse
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func validate(_ request: ChatSendRequest) throws {
        let idPattern = #"^[A-Za-z0-9._:-]{8,128}$"#
        let message = request.message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard request.requestId.range(of: idPattern, options: .regularExpression) != nil,
              request.conversationId.range(of: idPattern, options: .regularExpression) != nil,
              message.count <= 4000,
              !message.isEmpty else {
            throw ChatContractError.invalidRequest
        }
    }

    private func validateIdentity(
        _ payload: RemoteChatStreamPayload,
        request: ChatSendRequest
    ) throws {
        guard payload.requestId == request.requestId,
              payload.conversationId == request.conversationId else {
            throw ChatContractError.mismatchedResponse
        }
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
    let makeupGeneration: RemoteMakeupGenerationService
    let makeupRecommendation: RemoteMakeupRecommendationService

    init(configuration: APIConfiguration) {
        let client = APIClient(configuration: configuration)
        self.client = client
        self.authentication = RemoteAuthenticationService(client: client)
        self.chat = RemoteAIAgentService(client: client)
        self.makeupGeneration = RemoteMakeupGenerationService(client: client)
        self.makeupRecommendation = RemoteMakeupRecommendationService(client: client)
    }
}
