import Foundation
import OSLog
import UIKit

enum VisionLog {
    static let pipeline = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.makeup.chat",
        category: "VisionPipeline"
    )
}

enum VisionRequestStage: String, Sendable {
    case preparingImage = "准备图片"
    case submittingJob = "提交分析任务"
    case pollingJob = "查询分析任务"
    case processingResult = "处理分析结果"
    case savingProfile = "保存用户档案"
}

struct VisionRequestFailure: LocalizedError, Sendable {
    let visionError: VisionAPIError
    let stage: VisionRequestStage
    let userMessage: String
    let httpStatus: Int?
    let serverCode: String?
    let serverRequestID: String?

    init(
        visionError: VisionAPIError,
        stage: VisionRequestStage,
        userMessage: String? = nil,
        httpStatus: Int? = nil,
        serverCode: String? = nil,
        serverRequestID: String? = nil
    ) {
        self.visionError = visionError
        self.stage = stage
        self.userMessage = userMessage ?? visionError.localizedDescription
        self.httpStatus = httpStatus
        self.serverCode = serverCode
        self.serverRequestID = serverRequestID
    }

    static func capturing(_ error: Error, stage: VisionRequestStage) -> VisionRequestFailure {
        if let failure = error as? VisionRequestFailure { return failure }
        if let apiError = error as? APIClientError {
            let mapped = mappedVisionError(apiError)
            let message: String
            switch apiError {
            case .problem(let problem, _):
                message = problem.detail ?? problem.title
            case .httpStatus(_, let value, _, _):
                message = value
            default:
                message = mapped.localizedDescription
            }
            return VisionRequestFailure(
                visionError: mapped,
                stage: stage,
                userMessage: message,
                httpStatus: apiError.statusCode,
                serverCode: apiError.problemCode,
                serverRequestID: apiError.diagnosticRequestID
            )
        }
        let mapped = normalizedVisionError(error)
        return VisionRequestFailure(
            visionError: mapped,
            stage: stage,
            userMessage: error.localizedDescription
        )
    }

    var diagnosticCode: String {
        serverCode ?? stableVisionErrorCode(visionError)
    }

    var errorDescription: String? {
        var lines = [userMessage, "阶段：\(stage.rawValue)"]
        if let httpStatus { lines.append("HTTP 状态：\(httpStatus)") }
        lines.append("错误码：\(diagnosticCode)")
        if let serverRequestID, !serverRequestID.isEmpty {
            lines.append("请求编号：\(serverRequestID)")
        }
        return lines.joined(separator: "\n")
    }
}

@discardableResult
func visionFailureMessage(
    _ error: Error,
    fallbackStage: VisionRequestStage
) -> String {
    let failure = VisionRequestFailure.capturing(error, stage: fallbackStage)
    let status = failure.httpStatus.map(String.init) ?? "none"
    let requestID = failure.serverRequestID ?? "none"
    VisionLog.pipeline.error(
        "Vision request failed stage=\(failure.stage.rawValue, privacy: .public) code=\(failure.diagnosticCode, privacy: .public) http=\(status, privacy: .public) request_id=\(requestID, privacy: .public)"
    )
    return failure.localizedDescription
}

func mappedVisionError(_ error: APIClientError) -> VisionAPIError {
    switch error.problemCode?.uppercased() {
    case "DEMO_FIXTURE_NOT_RECOGNIZED": return .demoFixtureNotRecognized
    case "DEMO_FIXTURE_MISMATCH": return .demoFixtureMismatch
    case "DEMO_CACHE_NOT_READY": return .demoCacheNotReady
    case "DEMO_VARIANT_NOT_FOUND": return .demoVariantNotFound
    case "PAYLOAD_TOO_LARGE": return .payloadTooLarge
    case "UNSUPPORTED_MEDIA_TYPE": return .unsupportedMediaType
    default: break
    }
    if error.statusCode == 401 { return .unauthorized }
    if error.statusCode == 404 { return .jobNotFound }
    if [413, 415, 422].contains(error.statusCode) { return .invalidImage }
    if let status = error.statusCode, (200..<300).contains(status) { return .resultInvalid }
    if error.statusCode != nil { return .serverError }
    switch error {
    case .networkUnavailable: return .networkUnavailable
    case .invalidImage: return .invalidImage
    case .invalidResponse, .invalidServerResponse, .problem, .httpStatus: return .resultInvalid
    }
}

func stableVisionErrorCode(_ error: Error) -> String {
    if let failure = error as? VisionRequestFailure { return failure.diagnosticCode }
    if let error = error as? VisionAPIError {
        switch error {
        case .configurationMissing: return "configuration_missing"
        case .configurationInvalid: return "configuration_invalid"
        case .unauthorized: return "unauthorized"
        case .invalidImage: return "invalid_image"
        case .uploadFailed: return "upload_failed"
        case .jobNotFound: return "job_not_found"
        case .providerUnavailable: return "provider_unavailable"
        case .jobTimedOut: return "job_timed_out"
        case .resultInvalid: return "result_invalid"
        case .networkUnavailable: return "network_unavailable"
        case .serverError: return "server_error"
        case .cancelled: return "cancelled"
        case .demoFixtureNotRecognized: return "demo_fixture_not_recognized"
        case .demoFixtureMismatch: return "demo_fixture_mismatch"
        case .demoCacheNotReady: return "demo_cache_not_ready"
        case .demoVariantNotFound: return "demo_variant_not_found"
        case .payloadTooLarge: return "payload_too_large"
        case .unsupportedMediaType: return "unsupported_media_type"
        }
    }
    if let error = error as? APIClientError {
        if let code = error.problemCode, !code.isEmpty { return code.lowercased() }
        if let status = error.statusCode { return "http_\(status)" }
        switch error {
        case .networkUnavailable: return "network_unavailable"
        case .invalidResponse, .invalidServerResponse: return "result_invalid"
        case .invalidImage: return "invalid_image"
        case .problem, .httpStatus: return "unknown"
        }
    }
    if let error = error as? APIConfigurationError {
        switch error {
        case .configurationMissing: return "configuration_missing"
        case .configurationInvalid: return "configuration_invalid"
        }
    }
    if error is URLError { return "network_unavailable" }
    return "unknown"
}

func normalizedVisionError(_ error: Error) -> VisionAPIError {
    if error is CancellationError { return .cancelled }
    if let failure = error as? VisionRequestFailure { return failure.visionError }
    if let error = error as? VisionAPIError { return error }
    if let error = error as? APIConfigurationError {
        switch error {
        case .configurationMissing: return .configurationMissing
        case .configurationInvalid: return .configurationInvalid
        }
    }
    if let error = error as? APIClientError {
        return mappedVisionError(error)
    }
    if error is URLError { return .networkUnavailable }
    return .providerUnavailable
}

enum VisionAPIError: LocalizedError, Equatable, Sendable {
    case configurationMissing
    case configurationInvalid
    case unauthorized
    case invalidImage
    case uploadFailed
    case jobNotFound
    case providerUnavailable
    case jobTimedOut
    case resultInvalid
    case networkUnavailable
    case serverError
    case cancelled
    case demoFixtureNotRecognized
    case demoFixtureMismatch
    case demoCacheNotReady
    case demoVariantNotFound
    case payloadTooLarge
    case unsupportedMediaType

    var errorDescription: String? {
        switch self {
        case .configurationMissing: return "当前 App 未配置 AuraEye API 地址，请检查构建配置。"
        case .configurationInvalid: return "当前 App 的 AuraEye API 地址无效，请检查构建配置。"
        case .unauthorized: return "登录状态已失效，请重新登录。"
        case .invalidImage: return "图片无法处理，请重新选择。"
        case .uploadFailed: return "图片上传失败，请检查网络后重试。"
        case .jobNotFound: return "分析任务不存在或已失效。"
        case .providerUnavailable: return "视觉分析服务暂时不可用。"
        case .jobTimedOut: return "分析时间较长，稍后返回页面会继续查询原任务。"
        case .resultInvalid: return "分析结果格式暂时无法识别。"
        case .networkUnavailable: return "网络不可用，请检查连接后重试。"
        case .serverError: return "服务器请求失败，请稍后重试。"
        case .cancelled: return "分析已取消。"
        case .demoFixtureNotRecognized: return "请选择指定的演示图片。"
        case .demoFixtureMismatch: return "图片与演示能力不匹配。"
        case .demoCacheNotReady: return "该演示结果尚未准备完成。"
        case .demoVariantNotFound: return "该试妆组合尚未预置。"
        case .payloadTooLarge: return "图片大小超过限制，请重新选择。"
        case .unsupportedMediaType: return "暂不支持该图片格式，请重新选择。"
        }
    }
}

/// 相册来源始终保留原始字节；相机来源仅在没有文件字节时编码一次用于统一任务提交。
struct VisionImageInput {
    let image: UIImage
    let originalData: Data?
    let contentType: String?

    init(image: UIImage) {
        self.image = image
        self.originalData = nil
        self.contentType = nil
    }

    init(photoData: Data, contentType: String) throws {
        guard contentType.lowercased().hasPrefix("image/") else {
            throw VisionAPIError.unsupportedMediaType
        }
        guard let image = UIImage(data: photoData) else {
            throw VisionAPIError.invalidImage
        }
        self.image = image
        self.originalData = photoData
        self.contentType = contentType
    }

    func requestPayload() throws -> (data: Data, mimeType: String) {
        if let originalData, let contentType {
            return (originalData, contentType)
        }
        guard let encoded = image.jpegData(compressionQuality: 0.95) else {
            throw VisionAPIError.invalidImage
        }
        return (encoded, "image/jpeg")
    }
}

enum VisionCapability: String, Codable, Sendable {
    case faceAnalysis = "face_analysis"
    case itemRecognition = "item_recognition"
    case makeupRender = "makeup_render"

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case Self.faceAnalysis.rawValue, "visual_profile": self = .faceAnalysis
        case Self.itemRecognition.rawValue: self = .itemRecognition
        case Self.makeupRender.rawValue: self = .makeupRender
        default: throw VisionAPIError.resultInvalid
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct FaceAnalysisJobOptions: Encodable, Sendable {
    let consentVersion: String

    init(consentVersion: String = "visual-analysis-test-v1") {
        self.consentVersion = consentVersion
    }

    enum CodingKeys: String, CodingKey {
        case consentVersion = "consent_version"
    }
}

struct ItemRecognitionJobOptions: Encodable, Sendable {
    let recognitionScope: RecognitionScope

    init(
        allowedCategories: [String] = ["makeup_brush", "eyeliner", "eyeshadow_palette"],
        maxItems: Int = 3
    ) {
        recognitionScope = RecognitionScope(
            allowedCategories: allowedCategories,
            maxItems: min(max(maxItems, 1), 3)
        )
    }

    enum CodingKeys: String, CodingKey {
        case recognitionScope = "recognition_scope"
    }

    struct RecognitionScope: Encodable, Sendable {
        let allowedCategories: [String]
        let maxItems: Int

        enum CodingKeys: String, CodingKey {
            case allowedCategories = "allowed_categories"
            case maxItems = "max_items"
        }
    }
}

struct MakeupRenderJobOptions: Encodable, Sendable {
    let recipeID: String

    init(recipeID: String = "perfect-live-1785130914911") {
        self.recipeID = recipeID
    }

    enum CodingKeys: String, CodingKey {
        case recipeID = "recipe_id"
    }
}

enum VisionJobOptions: Sendable {
    case faceAnalysis(FaceAnalysisJobOptions)
    case itemRecognition(ItemRecognitionJobOptions)
    case makeupRender(MakeupRenderJobOptions)

    func jsonString() throws -> String {
        let data: Data
        switch self {
        case .faceAnalysis(let value):
            data = try JSONEncoder.visionEncoder.encode(value)
        case .itemRecognition(let value):
            data = try JSONEncoder.visionEncoder.encode(value)
        case .makeupRender(let value):
            data = try JSONEncoder.visionEncoder.encode(value)
        }
        return String(decoding: data, as: UTF8.self)
    }
}

struct VisionJobTicketDTO: Codable, Sendable {
    let jobId: String
    let capability: VisionCapability
    let status: AIJobStatus

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case capability = "job_type"
        case status
    }
}

final class VisionJobService {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func create(
        input: VisionImageInput,
        capability: VisionCapability,
        options: VisionJobOptions? = nil,
        requestID: String,
        idempotencyKey: String
    ) async throws -> APIResponse<VisionJobTicketDTO> {
        let payload: (data: Data, mimeType: String)
        do {
            payload = try input.requestPayload()
        } catch {
            throw VisionRequestFailure.capturing(error, stage: .preparingImage)
        }
        var fields = [
            "request_id": requestID,
            "capability": capability.rawValue
        ]
        if let options {
            fields["options"] = try options.jsonString()
        }
        do {
            return try await client.sendMultipartResponse(
                path: APIEndpoint.visionJobs,
                fields: fields,
                imageData: payload.data,
                imageContentType: payload.mimeType,
                idempotencyKey: idempotencyKey,
                expectedStatusCode: 202
            )
        } catch let error as APIClientError {
            throw VisionRequestFailure.capturing(error, stage: .submittingJob)
        }
    }
}

enum AsyncAnalysisState<Result> {
    case idle
    case preparingImage
    case uploading(progress: Double)
    case submitting
    case processing(stage: String?)
    case succeeded(Result)
    case failed(VisionAPIError)
}

enum JSONValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([String: JSONValue].self) { self = .object(value) }
        else if let value = try? container.decode([JSONValue].self) { self = .array(value) }
        else { throw VisionAPIError.resultInvalid }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

// MARK: - Async jobs

enum AIJobStatus: Codable, Sendable {
    case queued
    case running
    case succeeded
    case failed
    case timedOut
    case cancelled

    var rawValue: String {
        switch self {
        case .queued: return "queued"
        case .running: return "running"
        case .succeeded: return "succeeded"
        case .failed: return "failed"
        case .timedOut: return "timed_out"
        case .cancelled: return "cancelled"
        }
    }

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case "queued": self = .queued
        case "running": self = .running
        case "succeeded": self = .succeeded
        case "failed": self = .failed
        case "timed_out": self = .timedOut
        case "cancelled", "canceled": self = .cancelled
        default: throw VisionAPIError.resultInvalid
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var isTerminal: Bool {
        switch self {
        case .succeeded, .failed, .timedOut, .cancelled: return true
        case .queued, .running: return false
        }
    }
}

struct AIJobProgressDTO: Codable, Sendable {
    let stage: String?
    let pollAfterMilliseconds: Int?

    enum CodingKeys: String, CodingKey {
        case stage
        case pollAfterMilliseconds = "poll_after_ms"
    }
}

struct AIJobErrorDTO: Codable, Sendable {
    let code: String?
    let message: String?
}

struct AIJobDTO<Result: Codable & Sendable>: Codable, Sendable {
    let jobId: String
    let requestId: String?
    let status: AIJobStatus
    let progress: AIJobProgressDTO?
    let result: Result?
    let error: AIJobErrorDTO?

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case requestId = "request_id"
        case status, progress, result, error
    }
}

final class AIJobRepository {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func job<Result: Codable & Sendable>(id: String) async throws -> APIResponse<AIJobDTO<Result>> {
        try await client.sendResponse(
            path: APIEndpoint.visionJob(id),
            expectedStatusCode: 200
        )
    }
}

final class VisionResultImageService {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func downloadPNG(jobID: String) async throws -> APIBinaryResponse {
        try await client.downloadResponse(
            path: APIEndpoint.visionJobResultImage(jobID),
            expectedContentType: "image/png"
        )
    }
}

protocol MakeupRenderProviding {
    func render(input: VisionImageInput, accountID: String) async throws -> String
}

final class UnifiedMakeupRenderProvider: MakeupRenderProviding {
    private let service: VisionJobService
    private let jobs: AIJobRepository
    private let images: VisionResultImageService
    private let poller: JobPoller
    private let persistence: VisionJobPersistence

    init(
        client: APIClient,
        poller: JobPoller = JobPoller(),
        persistence: VisionJobPersistence = VisionJobPersistence()
    ) {
        service = VisionJobService(client: client)
        jobs = AIJobRepository(client: client)
        images = VisionResultImageService(client: client)
        self.poller = poller
        self.persistence = persistence
    }

    func render(input: VisionImageInput, accountID: String) async throws -> String {
        let capability = VisionCapability.makeupRender
        let pending = try persistence.pendingJob(accountID: accountID, capability: capability)
        let requestID = pending?.requestID ?? "req_render_\(UUID().uuidString.lowercased())"
        let idempotencyKey = pending?.idempotencyKey ?? "idem_\(UUID().uuidString.lowercased())"

        if pending == nil {
            try persistence.savePendingJob(VisionPendingJob(
                accountID: accountID, capability: capability, requestID: requestID,
                idempotencyKey: idempotencyKey, jobID: nil, status: "submitting",
                serverRequestID: nil, location: nil, retryAfterSeconds: nil
            ))
        }

        var jobID = pending?.jobID
        if jobID == nil {
            let response = try await service.create(
                input: input,
                capability: capability,
                options: .makeupRender(.init()),
                requestID: requestID,
                idempotencyKey: idempotencyKey
            )
            guard response.value.capability == capability else { throw VisionAPIError.resultInvalid }
            jobID = response.value.jobId
            try persistence.savePendingJob(VisionPendingJob(
                accountID: accountID, capability: capability, requestID: requestID,
                idempotencyKey: idempotencyKey, jobID: response.value.jobId,
                status: response.value.status.rawValue,
                serverRequestID: response.metadata.serverRequestID,
                location: response.metadata.location,
                retryAfterSeconds: response.metadata.retryAfterSeconds
            ))
        }
        guard let jobID else { throw VisionAPIError.jobNotFound }

        let _: JSONValue = try await poller.poll(jobID: jobID, fetch: { [jobs] in
            try await jobs.job(id: $0)
        })
        let response = try await images.downloadPNG(jobID: jobID)
        guard let image = UIImage(data: response.data) else { throw VisionAPIError.resultInvalid }
        let path = try LocalMediaStore.savePNGImage(
            image,
            bucket: .eyePreviews,
            fileName: "makeup_render_\(jobID).png"
        )
        try persistence.removePendingJob(accountID: accountID, capability: capability)
        return path
    }
}

final class AccountAwareMakeupRenderProvider: MakeupRenderProviding {
    func render(input: VisionImageInput, accountID: String) async throws -> String {
        do {
            let client = try await MainActor.run { try VisionClientFactory.authenticatedClient() }
            return try await UnifiedMakeupRenderProvider(client: client).render(input: input, accountID: accountID)
        } catch {
            let failure = VisionRequestFailure.capturing(error, stage: .processingResult)
            _ = visionFailureMessage(failure, fallbackStage: .processingResult)
            throw failure
        }
    }
}

struct JobPoller {
    let maximumWait: TimeInterval
    let defaultPollMilliseconds: Int

    init(maximumWait: TimeInterval = 90, defaultPollMilliseconds: Int = 750) {
        self.maximumWait = maximumWait
        self.defaultPollMilliseconds = defaultPollMilliseconds
    }

    func poll<Result: Codable & Sendable>(
        jobID: String,
        fetch: @escaping (String) async throws -> APIResponse<AIJobDTO<Result>>,
        refreshAuthorization: @escaping () async throws -> Bool = { false },
        onResponse: @escaping (APIResponseMetadata) -> Void = { _ in },
        onProgress: @escaping (AIJobProgressDTO?) -> Void = { _ in }
    ) async throws -> Result {
        let deadline = Date().addingTimeInterval(maximumWait)
        var didAttemptAuthorizationRefresh = false
        var transientRetryCount = 0

        while !Task.isCancelled {
            let response: APIResponse<AIJobDTO<Result>>
            do {
                response = try await fetch(jobID)
                transientRetryCount = 0
            } catch let error as APIClientError {
                if error.statusCode == 401, !didAttemptAuthorizationRefresh {
                    didAttemptAuthorizationRefresh = true
                    if try await refreshAuthorization() { continue }
                }
                if error.statusCode == 409 {
                    throw VisionRequestFailure.capturing(error, stage: .pollingJob)
                }
                if [429, 503].contains(error.statusCode), error.permitsControlledRetry {
                    guard Date() < deadline else { throw VisionAPIError.jobTimedOut }
                    transientRetryCount += 1
                    let fallback = min(
                        defaultPollMilliseconds * (1 << min(transientRetryCount - 1, 3)),
                        5_000
                    )
                    let requested = error.responseMetadata?.retryAfterSeconds.map { $0 * 1_000 } ?? fallback
                    try await sleep(milliseconds: requested, deadline: deadline)
                    continue
                }
                throw VisionRequestFailure.capturing(error, stage: .pollingJob)
            }

            let job = response.value
            onResponse(response.metadata)
            VisionLog.pipeline.debug(
                "Polled job=\(jobID, privacy: .public) status=\(job.status.rawValue, privacy: .public)"
            )
            onProgress(job.progress)

            switch job.status {
            case .succeeded:
                guard let result = job.result else {
                    throw VisionRequestFailure(
                        visionError: .resultInvalid,
                        stage: .processingResult,
                        httpStatus: 200,
                        serverRequestID: response.metadata.serverRequestID ?? job.requestId
                    )
                }
                return result
            case .failed:
                throw VisionRequestFailure(
                    visionError: .providerUnavailable,
                    stage: .processingResult,
                    userMessage: job.error?.message,
                    httpStatus: 200,
                    serverCode: job.error?.code,
                    serverRequestID: response.metadata.serverRequestID ?? job.requestId
                )
            case .timedOut:
                throw VisionAPIError.jobTimedOut
            case .cancelled:
                throw VisionAPIError.cancelled
            case .queued, .running:
                guard Date() < deadline else { throw VisionAPIError.jobTimedOut }
                let requested = response.metadata.retryAfterSeconds.map { $0 * 1_000 }
                    ?? job.progress?.pollAfterMilliseconds
                    ?? defaultPollMilliseconds
                try await sleep(milliseconds: requested, deadline: deadline)
            }
        }
        throw VisionAPIError.cancelled
    }

    private func sleep(milliseconds: Int, deadline: Date) async throws {
        let remainingMilliseconds = max(Int(deadline.timeIntervalSinceNow * 1_000), 0)
        guard remainingMilliseconds > 0 else { throw VisionAPIError.jobTimedOut }
        let bounded = min(max(milliseconds, 0), remainingMilliseconds)
        try await Task.sleep(for: .milliseconds(bounded))
    }
}

enum VisionClientFactory {
    @MainActor
    static func authenticatedClient() throws -> APIClient {
        guard let context = SessionManager.shared.context else {
            throw VisionAPIError.unauthorized
        }
        return try APIEnvironment.shared.authenticatedClient(accessToken: context.accessToken)
    }
}
