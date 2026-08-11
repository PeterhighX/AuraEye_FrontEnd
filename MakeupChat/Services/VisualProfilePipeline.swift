import Foundation
import UIKit

struct PortraitInput {
    let image: UIImage
    let originalData: Data?
    let contentType: String?
    let userID: String

    var visionInput: VisionImageInput {
        if let originalData, let contentType,
           let input = try? VisionImageInput(photoData: originalData, contentType: contentType) {
            return input
        }
        return VisionImageInput(image: image)
    }
}

struct VisualProfileSnapshotDTO: Codable, Equatable, Sendable {
    let face: [String: JSONValue]
    let eyes: [String: JSONValue]
    let brows: [String: JSONValue]
    let skin: [String: JSONValue]
    let provenance: [JSONValue]
}

struct VisualProfileNarrativeDTO: Codable, Equatable, Sendable {
    let overall: String?
    let eyeDetails: String?
    let styleRecommendation: String?

    enum CodingKeys: String, CodingKey {
        case overall = "overall_contour"
        case eyeDetails = "brow_eye_detail"
        case styleRecommendation = "style_recommendation"
    }
}

struct VisualProfileResultDTO: Codable, Equatable, Sendable {
    let profileSnapshot: VisualProfileSnapshotDTO
    let narrative: VisualProfileNarrativeDTO?
    let narrativeStatus: String?
    let warnings: [String]

    enum CodingKeys: String, CodingKey {
        case profileSnapshot = "profile_snapshot"
        case narrative
        case narrativeStatus = "narrative_status"
        case warnings
    }
}

struct VisualProfileResult {
    let dto: VisualProfileResultDTO
    let portraitPath: String
}

protocol VisualProfileProviding {
    func analyzePortrait(_ input: PortraitInput) async throws -> VisualProfileResult
}

final class UnifiedVisualProfileProvider: VisualProfileProviding {
    private let service: VisionJobService
    private let jobs: AIJobRepository
    private let poller: JobPoller
    private let persistence: VisionJobPersistence

    init(
        client: APIClient,
        poller: JobPoller = JobPoller(),
        persistence: VisionJobPersistence = VisionJobPersistence()
    ) {
        service = VisionJobService(client: client)
        jobs = AIJobRepository(client: client)
        self.poller = poller
        self.persistence = persistence
    }

    func analyzePortrait(_ input: PortraitInput) async throws -> VisualProfileResult {
        let capability = VisionCapability.faceAnalysis
        let pending = try persistence.pendingJob(accountID: input.userID, capability: capability)
        let requestID = pending?.requestID ?? "req_profile_\(UUID().uuidString.lowercased())"
        let idempotencyKey = pending?.idempotencyKey ?? "idem_\(UUID().uuidString.lowercased())"

        if pending == nil {
            try persistence.savePendingJob(VisionPendingJob(
                accountID: input.userID,
                capability: capability,
                requestID: requestID,
                idempotencyKey: idempotencyKey,
                jobID: nil,
                status: "submitting",
                serverRequestID: nil,
                location: nil,
                retryAfterSeconds: nil
            ))
        }

        do {
            var jobID = pending?.jobID
            if jobID == nil {
                let response = try await service.create(
                    input: input.visionInput,
                    capability: capability,
                    options: .faceAnalysis(.init()),
                    requestID: requestID,
                    idempotencyKey: idempotencyKey
                )
                guard response.value.capability == capability else {
                    throw VisionAPIError.resultInvalid
                }
                jobID = response.value.jobId
                try persistence.savePendingJob(VisionPendingJob(
                    accountID: input.userID,
                    capability: capability,
                    requestID: requestID,
                    idempotencyKey: idempotencyKey,
                    jobID: response.value.jobId,
                    status: response.value.status.rawValue,
                    serverRequestID: response.metadata.serverRequestID,
                    location: response.metadata.location,
                    retryAfterSeconds: response.metadata.retryAfterSeconds
                ))
            }
            guard let jobID else { throw VisionAPIError.jobNotFound }

            let dto: VisualProfileResultDTO = try await poller.poll(
                jobID: jobID,
                fetch: { [jobs] in try await jobs.job(id: $0) },
                onResponse: { [persistence] metadata in
                    try? persistence.savePendingJob(VisionPendingJob(
                        accountID: input.userID,
                        capability: capability,
                        requestID: requestID,
                        idempotencyKey: idempotencyKey,
                        jobID: jobID,
                        status: "polling",
                        serverRequestID: metadata.serverRequestID,
                        location: metadata.location,
                        retryAfterSeconds: metadata.retryAfterSeconds
                    ))
                }
            )
            try persistence.removePendingJob(accountID: input.userID, capability: capability)
            let portraitPath: String
            if let originalData = input.originalData, let contentType = input.contentType {
                portraitPath = try LocalMediaStore.saveData(
                    originalData,
                    bucket: .portraits,
                    fileName: "visual_profile_\(input.userID).\(Self.fileExtension(for: contentType))"
                )
            } else {
                portraitPath = try LocalMediaStore.saveImage(
                    input.image,
                    bucket: .portraits,
                    fileName: "visual_profile_\(input.userID).jpg"
                )
            }
            return VisualProfileResult(dto: dto, portraitPath: portraitPath)
        } catch let failure as VisionRequestFailure {
            if [.providerUnavailable, .cancelled, .demoFixtureNotRecognized,
                .demoFixtureMismatch, .demoCacheNotReady, .payloadTooLarge,
                .unsupportedMediaType].contains(failure.visionError) {
                try? persistence.removePendingJob(accountID: input.userID, capability: capability)
            }
            throw failure
        } catch let error as VisionAPIError {
            if [.providerUnavailable, .cancelled, .demoFixtureNotRecognized,
                .demoFixtureMismatch, .demoCacheNotReady, .payloadTooLarge,
                .unsupportedMediaType].contains(error) {
                try? persistence.removePendingJob(accountID: input.userID, capability: capability)
            }
            throw error
        }
    }

    private static func fileExtension(for contentType: String) -> String {
        switch contentType.lowercased() {
        case "image/png": return "png"
        case "image/heic", "image/heif": return "heic"
        default: return "jpg"
        }
    }
}

final class AccountAwareVisualProfileProvider: VisualProfileProviding {
    func analyzePortrait(_ input: PortraitInput) async throws -> VisualProfileResult {
        guard await MainActor.run(body: { SessionManager.shared.context != nil }) else {
            throw VisionAPIError.unauthorized
        }
        do {
            let client = try await MainActor.run { try VisionClientFactory.authenticatedClient() }
            return try await UnifiedVisualProfileProvider(client: client).analyzePortrait(input)
        } catch {
            let failure = VisionRequestFailure.capturing(error, stage: .processingResult)
            _ = visionFailureMessage(failure, fallbackStage: .processingResult)
            throw failure
        }
    }
}

final class AccountAwareFaceAnalysisService: FaceAnalysisServicing {
    private let provider: VisualProfileProviding

    init(provider: VisualProfileProviding = AccountAwareVisualProfileProvider()) {
        self.provider = provider
    }

    func analyze(input: VisionImageInput, userId: String) async throws -> FaceAnalysisResult {
        let sessionUserID = await MainActor.run { SessionManager.shared.context?.userId }
        let result = try await provider.analyzePortrait(PortraitInput(
            image: input.image,
            originalData: input.originalData,
            contentType: input.contentType,
            userID: sessionUserID ?? userId
        ))
        let profileJSON = String(
            decoding: try JSONEncoder.visionEncoder.encode(result.dto),
            as: UTF8.self
        )
        return FaceAnalysisResult(
            portraitPath: result.portraitPath,
            profileJSON: profileJSON
        )
    }
}

extension JSONEncoder {
    static var visionEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}
