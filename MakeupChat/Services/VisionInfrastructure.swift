import CryptoKit
import Foundation
import OSLog
import UIKit

enum VisionLog {
    static let pipeline = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.makeup.chat",
        category: "VisionPipeline"
    )
}

func stableVisionErrorCode(_ error: Error) -> String {
    if let error = error as? VisionAPIError {
        switch error {
        case .unauthorized: return "unauthorized"
        case .invalidImage: return "invalid_image"
        case .uploadFailed: return "upload_failed"
        case .jobNotFound: return "job_not_found"
        case .providerUnavailable: return "provider_unavailable"
        case .jobTimedOut: return "job_timed_out"
        case .resultInvalid: return "result_invalid"
        case .networkUnavailable: return "network_unavailable"
        case .cancelled: return "cancelled"
        }
    }
    if let error = error as? APIClientError {
        switch error {
        case .missingBaseURL: return "network_unavailable"
        case .invalidResponse: return "result_invalid"
        case .invalidImage: return "invalid_image"
        case .httpStatus(let status, _): return "http_\(status)"
        }
    }
    if error is URLError { return "network_unavailable" }
    return "unknown"
}

func normalizedVisionError(_ error: Error) -> VisionAPIError {
    if let error = error as? VisionAPIError { return error }
    if let error = error as? APIClientError {
        switch error {
        case .missingBaseURL: return .networkUnavailable
        case .invalidResponse: return .resultInvalid
        case .invalidImage: return .invalidImage
        case .httpStatus(let status, _):
            if status == 401 { return .unauthorized }
            if status == 404 { return .jobNotFound }
            return status >= 500 ? .providerUnavailable : .resultInvalid
        }
    }
    if error is URLError { return .networkUnavailable }
    return .providerUnavailable
}

enum VisionAPIError: LocalizedError, Equatable, Sendable {
    case unauthorized
    case invalidImage
    case uploadFailed
    case jobNotFound
    case providerUnavailable
    case jobTimedOut
    case resultInvalid
    case networkUnavailable
    case cancelled

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "登录状态已失效，请重新登录。"
        case .invalidImage: return "图片无法处理，请重新选择。"
        case .uploadFailed: return "图片上传失败，请检查网络后重试。"
        case .jobNotFound: return "分析任务不存在或已失效。"
        case .providerUnavailable: return "视觉分析服务暂时不可用。"
        case .jobTimedOut: return "分析时间较长，稍后返回页面会继续查询原任务。"
        case .resultInvalid: return "分析结果格式暂时无法识别。"
        case .networkUnavailable: return "网络不可用，请检查连接后重试。"
        case .cancelled: return "分析已取消。"
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

// MARK: - Media assets

struct MediaUploadIntentDTO: Codable, Sendable {
    let assetId: String
    let uploadURL: URL
    let uploadMethod: String
    let uploadHeaders: [String: String]
    let expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case assetId = "asset_id"
        case uploadURL = "upload_url"
        case uploadMethod = "upload_method"
        case uploadHeaders = "upload_headers"
        case expiresAt = "expires_at"
    }
}

struct MediaAssetDTO: Codable, Sendable {
    let assetId: String
    let status: String?

    enum CodingKeys: String, CodingKey {
        case assetId = "asset_id"
        case status
    }
}

private struct CreateUploadIntentRequest: Encodable {
    let requestId: String
    let fileName: String
    let contentType: String
    let fileSize: Int
    let purpose: String

    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case fileName = "file_name"
        case contentType = "content_type"
        case fileSize = "file_size"
        case purpose
    }
}

private struct EmptyVisionRequest: Encodable {}

struct PreparedVisionImage: Sendable {
    let data: Data
    let fileName: String
    let contentType: String
    let sha256: String

    init(image: UIImage, fileName: String = "vision-input.jpg") throws {
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            throw VisionAPIError.invalidImage
        }
        self.data = data
        self.fileName = fileName
        self.contentType = "image/jpeg"
        self.sha256 = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

protocol MediaAssetRepositoryProtocol {
    func upload(
        _ image: PreparedVisionImage,
        requestID: String,
        onProgress: @escaping (Double) -> Void
    ) async throws -> MediaAssetDTO
}

final class MediaAssetRepository: MediaAssetRepositoryProtocol {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func upload(
        _ image: PreparedVisionImage,
        requestID: String,
        onProgress: @escaping (Double) -> Void = { _ in }
    ) async throws -> MediaAssetDTO {
        onProgress(0.05)
        VisionLog.pipeline.debug("Creating upload intent request=\(requestID, privacy: .public)")
        let intent: MediaUploadIntentDTO = try await client.sendFlexible(
            path: "/v1/media/upload-intents",
            body: CreateUploadIntentRequest(
                requestId: requestID,
                fileName: image.fileName,
                contentType: image.contentType,
                fileSize: image.data.count,
                purpose: "vision"
            ),
            requestID: requestID
        )

        onProgress(0.2)
        do {
            try await client.uploadBinary(
                to: intent.uploadURL,
                method: intent.uploadMethod,
                headers: intent.uploadHeaders,
                data: image.data
            )
        } catch {
            throw VisionAPIError.uploadFailed
        }
        onProgress(0.9)

        let asset: MediaAssetDTO = try await client.sendFlexible(
            path: "/v1/media/assets/\(intent.assetId)/complete",
            body: EmptyVisionRequest(),
            requestID: requestID
        )
        VisionLog.pipeline.debug("Completed media asset=\(asset.assetId, privacy: .public)")
        onProgress(1)
        return asset
    }
}

// MARK: - Async jobs

enum AIJobStatus: String, Codable, Sendable {
    case queued
    case running
    case succeeded
    case failed
    case timedOut = "timed_out"
    case cancelled

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

struct AIJobTicketDTO: Codable, Sendable {
    let contractVersion: String?
    let jobId: String
    let requestId: String
    let jobType: String
    let assetId: String
    let status: AIJobStatus
    let progress: AIJobProgressDTO?

    enum CodingKeys: String, CodingKey {
        case contractVersion = "contract_version"
        case jobId = "job_id"
        case requestId = "request_id"
        case jobType = "job_type"
        case assetId = "asset_id"
        case status, progress
    }
}

struct AIJobErrorDTO: Codable, Sendable {
    let code: String?
    let message: String?
}

struct AIJobDTO<Result: Codable & Sendable>: Codable, Sendable {
    let contractVersion: String?
    let jobId: String
    let requestId: String?
    let jobType: String?
    let assetId: String?
    let status: AIJobStatus
    let progress: AIJobProgressDTO?
    let result: Result?
    let error: AIJobErrorDTO?

    enum CodingKeys: String, CodingKey {
        case contractVersion = "contract_version"
        case jobId = "job_id"
        case requestId = "request_id"
        case jobType = "job_type"
        case assetId = "asset_id"
        case status, progress, result, error
    }
}

final class AIJobRepository {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func job<Result: Codable & Sendable>(id: String) async throws -> AIJobDTO<Result> {
        try await client.sendFlexible(path: "/v1/vision/jobs/\(id)")
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
        fetch: @escaping (String) async throws -> AIJobDTO<Result>,
        onProgress: @escaping (AIJobProgressDTO?) -> Void = { _ in }
    ) async throws -> Result {
        let deadline = Date().addingTimeInterval(maximumWait)

        while !Task.isCancelled {
            let job = try await fetch(jobID)
            VisionLog.pipeline.debug(
                "Polled job=\(jobID, privacy: .public) status=\(job.status.rawValue, privacy: .public)"
            )
            onProgress(job.progress)

            switch job.status {
            case .succeeded:
                guard let result = job.result else { throw VisionAPIError.resultInvalid }
                return result
            case .failed:
                throw VisionAPIError.providerUnavailable
            case .timedOut:
                throw VisionAPIError.jobTimedOut
            case .cancelled:
                throw VisionAPIError.cancelled
            case .queued, .running:
                guard Date() < deadline else { throw VisionAPIError.jobTimedOut }
                let requested = job.progress?.pollAfterMilliseconds ?? defaultPollMilliseconds
                let milliseconds = min(max(requested, 250), 5_000)
                try await Task.sleep(for: .milliseconds(milliseconds))
            }
        }
        throw VisionAPIError.cancelled
    }
}

enum VisionClientFactory {
    @MainActor
    static func authenticatedClient() throws -> APIClient {
        guard let context = SessionManager.shared.context else {
            throw VisionAPIError.unauthorized
        }
        let base = try APIConfiguration.fromBundle()
        return APIClient(configuration: APIConfiguration(
            baseURL: base.baseURL,
            accessToken: context.accessToken,
            timeout: base.timeout
        ))
    }
}
