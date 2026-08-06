import Foundation
import UIKit

struct PortraitInput {
    let image: UIImage
    let userID: String
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
        case overall
        case eyeDetails = "eye_details"
        case styleRecommendation = "style_recommendation"
    }
}

struct VisualProfileResultDTO: Codable, Equatable, Sendable {
    let profileSnapshot: VisualProfileSnapshotDTO
    let narrative: VisualProfileNarrativeDTO?
    let narrativeStatus: String?
    let warnings: [String]
    var resultSource: String?
    var schemaVersion: String?

    enum CodingKeys: String, CodingKey {
        case profileSnapshot = "profile_snapshot"
        case narrative
        case narrativeStatus = "narrative_status"
        case warnings
        case resultSource = "result_source"
        case schemaVersion = "schema_version"
    }
}

struct VisualProfileResult {
    let dto: VisualProfileResultDTO
    let portraitPath: String
}

protocol VisualProfileProviding {
    func analyzePortrait(_ input: PortraitInput) async throws -> VisualProfileResult
}

private struct CreateVisualProfileJobRequest: Encodable {
    let requestId: String
    let assetId: String
    let consentVersion: String

    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case assetId = "asset_id"
        case consentVersion = "consent_version"
    }
}

final class RemoteVisualProfileProvider: VisualProfileProviding {
    private let client: APIClient
    private let mediaRepository: MediaAssetRepositoryProtocol
    private let jobs: AIJobRepository
    private let poller: JobPoller
    private let persistence: DemoVisionRepository

    init(
        client: APIClient,
        mediaRepository: MediaAssetRepositoryProtocol? = nil,
        poller: JobPoller = JobPoller(),
        persistence: DemoVisionRepository = DemoVisionRepository()
    ) {
        self.client = client
        self.mediaRepository = mediaRepository ?? MediaAssetRepository(client: client)
        self.jobs = AIJobRepository(client: client)
        self.poller = poller
        self.persistence = persistence
    }

    func analyzePortrait(_ input: PortraitInput) async throws -> VisualProfileResult {
        let prepared = try PreparedVisionImage(image: input.image, fileName: "portrait.jpg")
        let capability = "visual_profile"
        var pending = try persistence.pendingJob(accountID: input.userID, capability: capability)

        if let existing = pending,
           existing.inputSHA256 != prepared.sha256,
           existing.jobID == nil {
            try persistence.removePendingJob(accountID: input.userID, capability: capability)
            pending = nil
        }

        let requestID = pending?.requestID ?? "req_profile_\(UUID().uuidString.lowercased())"
        if pending == nil {
            pending = VisionPendingJob(
                accountID: input.userID,
                capability: capability,
                requestID: requestID,
                jobID: nil,
                assetID: nil,
                inputSHA256: prepared.sha256,
                status: "preparing"
            )
            try persistence.savePendingJob(pending!)
        }

        var assetID = pending?.assetID
        if assetID == nil {
            let asset = try await mediaRepository.upload(prepared, requestID: requestID) { _ in }
            assetID = asset.assetId
            try persistence.savePendingJob(VisionPendingJob(
                accountID: input.userID,
                capability: capability,
                requestID: requestID,
                jobID: nil,
                assetID: asset.assetId,
                inputSHA256: prepared.sha256,
                status: "uploaded"
            ))
        }

        guard let assetID else { throw VisionAPIError.uploadFailed }
        var jobID = pending?.jobID
        if jobID == nil {
            let ticket: AIJobTicketDTO = try await client.sendFlexible(
                path: "/v1/vision/profile-jobs",
                body: CreateVisualProfileJobRequest(
                    requestId: requestID,
                    assetId: assetID,
                    consentVersion: "visual-analysis-v1"
                ),
                requestID: requestID
            )
            jobID = ticket.jobId
            try persistence.savePendingJob(VisionPendingJob(
                accountID: input.userID,
                capability: capability,
                requestID: requestID,
                jobID: ticket.jobId,
                assetID: assetID,
                inputSHA256: prepared.sha256,
                status: ticket.status.rawValue
            ))
        }

        guard let jobID else { throw VisionAPIError.jobNotFound }
        do {
            var dto: VisualProfileResultDTO = try await poller.poll(
                jobID: jobID,
                fetch: { [jobs] in try await jobs.job(id: $0) }
            )
            dto.resultSource = dto.resultSource ?? "remote_provider"
            dto.schemaVersion = dto.schemaVersion ?? DemoVisionRepository.schemaVersion
            try persistence.removePendingJob(accountID: input.userID, capability: capability)

            let portraitPath = try LocalMediaStore.saveImage(
                input.image,
                bucket: .portraits,
                fileName: "visual_profile_\(input.userID).jpg"
            )
            return VisualProfileResult(dto: dto, portraitPath: portraitPath)
        } catch let error as VisionAPIError {
            if error == .providerUnavailable || error == .cancelled {
                try? persistence.removePendingJob(accountID: input.userID, capability: capability)
            }
            throw error
        }
    }
}

final class DemoVisualProfileProvider: VisualProfileProviding {
    private let persistence: DemoVisionRepository

    init(persistence: DemoVisionRepository = DemoVisionRepository()) {
        self.persistence = persistence
    }

    func analyzePortrait(_ input: PortraitInput) async throws -> VisualProfileResult {
        guard let asset = try persistence.asset(key: "demo_portrait_01"),
              let cachedPortrait = UIImage(named: asset.localResourceName) else {
            throw VisionAPIError.resultInvalid
        }
        guard DemoImageMatcher.isSameImage(input.image, cachedPortrait) else {
            VisionLog.pipeline.info("Demo portrait cache miss; routing selected image to remote profile job")
            do {
                let client = try await MainActor.run { try VisionClientFactory.authenticatedClient() }
                return try await RemoteVisualProfileProvider(client: client).analyzePortrait(input)
            } catch {
                throw normalizedVisionError(error)
            }
        }
        VisionLog.pipeline.info("Demo portrait cache hit asset=\(asset.key, privacy: .public)")
        let dto: VisualProfileResultDTO
        if let stored = try persistence.result(
            accountID: input.userID,
            capability: "visual_profile",
            asset: asset
        ), let data = stored.json.data(using: .utf8) {
            dto = try JSONDecoder().decode(VisualProfileResultDTO.self, from: data)
        } else {
            guard let seed = NSDataAsset(name: "DemoVisualProfileSeed")?.data else {
                throw VisionAPIError.resultInvalid
            }
            var seeded = try JSONDecoder().decode(VisualProfileResultDTO.self, from: seed)
            seeded.resultSource = "demo_seed"
            seeded.schemaVersion = DemoVisionRepository.schemaVersion
            let json = String(decoding: try JSONEncoder.visionEncoder.encode(seeded), as: UTF8.self)
            try persistence.saveResult(
                accountID: input.userID,
                capability: "visual_profile",
                asset: asset,
                source: "demo_seed",
                json: json
            )
            dto = seeded
        }

        // 仅保留短暂的真实状态过渡，不模拟长网络等待。
        try await Task.sleep(for: .milliseconds(180))
        let portraitPath = try LocalMediaStore.savePNGImage(
            input.image,
            bucket: .portraits,
            fileName: "demo_visual_profile_\(input.userID).png"
        )
        return VisualProfileResult(dto: dto, portraitPath: portraitPath)
    }
}

/// 在调用时读取集中 SessionContext，因此即使 ViewModel 在登录前创建也不会选错实现。
final class AccountAwareVisualProfileProvider: VisualProfileProviding {
    func analyzePortrait(_ input: PortraitInput) async throws -> VisualProfileResult {
        let context = await MainActor.run { SessionManager.shared.context }
        guard let context else { throw VisionAPIError.unauthorized }
        if context.accountMode == .demo, context.features.useDemoAssets {
            VisionLog.pipeline.info("Visual profile route=demo")
            return try await DemoVisualProfileProvider().analyzePortrait(input)
        }
        VisionLog.pipeline.info("Visual profile route=standard")
        do {
            let client = try await MainActor.run { try VisionClientFactory.authenticatedClient() }
            return try await RemoteVisualProfileProvider(client: client).analyzePortrait(input)
        } catch {
            throw normalizedVisionError(error)
        }
    }
}

/// 兼容现有 ViewModel 的适配层；页面继续消费原有 `FaceAnalysisResult`。
final class AccountAwareFaceAnalysisService: FaceAnalysisServicing {
    private let provider: VisualProfileProviding

    init(provider: VisualProfileProviding = AccountAwareVisualProfileProvider()) {
        self.provider = provider
    }

    func analyze(image: UIImage, userId: String) async throws -> FaceAnalysisResult {
        let sessionUserID = await MainActor.run { SessionManager.shared.context?.userId }
        let result = try await provider.analyzePortrait(PortraitInput(
            image: image,
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
