import Foundation
import UIKit

struct RecognitionInput {
    let image: UIImage
    let userID: String
    let categoryHint: CosmeticCategory?
}

struct RecognitionColorDTO: Codable, Equatable, Sendable {
    let hex: String
    let proportion: Double?

    private enum CodingKeys: String, CodingKey {
        case hex
        case proportion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let hex = try? container.decode(String.self) {
            self.hex = hex
            self.proportion = nil
            return
        }
        let object = try decoder.container(keyedBy: CodingKeys.self)
        hex = try object.decode(String.self, forKey: .hex)
        proportion = try object.decodeIfPresent(Double.self, forKey: .proportion)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hex, forKey: .hex)
        try container.encodeIfPresent(proportion, forKey: .proportion)
    }
}

struct RecognizedItemDTO: Codable, Equatable, Sendable {
    let itemIndex: Int
    let category: String
    let categoryLabelZH: String
    let categoryConfidence: Double?
    let boundingBox: [Int]?
    let brandText: String?
    let productNameText: String?
    let shadeText: String?
    let visibleTexts: [String]
    let colors: [RecognitionColorDTO]
    let needsConfirmation: Bool
    let knowledgeKeys: [String]

    enum CodingKeys: String, CodingKey {
        case itemIndex = "item_index"
        case category
        case categoryLabelZH = "category_label_zh"
        case categoryConfidence = "category_confidence"
        case boundingBox = "bbox_0_999"
        case brandText = "brand_text"
        case productNameText = "product_name_text"
        case shadeText = "shade_text"
        case visibleTexts = "visible_texts"
        case colors
        case needsConfirmation = "needs_confirmation"
        case knowledgeKeys = "knowledge_keys"
    }
}

struct ItemRecognitionResultDTO: Codable, Equatable, Sendable {
    let recognitionLevel: String
    let items: [RecognizedItemDTO]
    var warnings: [String]
    let knowledgeKeys: [String]
    var resultSource: String?
    var schemaVersion: String?

    enum CodingKeys: String, CodingKey {
        case recognitionLevel = "recognition_level"
        case items, warnings
        case knowledgeKeys = "knowledge_keys"
        case resultSource = "result_source"
        case schemaVersion = "schema_version"
    }
}

protocol ItemRecognitionProviding {
    func recognizeItem(_ input: RecognitionInput) async throws -> CosmeticsRecognitionResult
}

private struct RecognitionScopeDTO: Encodable {
    let allowedCategories: [String]
    let maxItems: Int

    enum CodingKeys: String, CodingKey {
        case allowedCategories = "allowed_categories"
        case maxItems = "max_items"
    }
}

private struct CreateItemRecognitionJobRequest: Encodable {
    let requestId: String
    let assetId: String
    let recognitionScope: RecognitionScopeDTO

    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case assetId = "asset_id"
        case recognitionScope = "recognition_scope"
    }
}

final class RemoteItemRecognitionProvider: ItemRecognitionProviding {
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

    func recognizeItem(_ input: RecognitionInput) async throws -> CosmeticsRecognitionResult {
        let prepared = try PreparedVisionImage(image: input.image, fileName: "item.jpg")
        let capability = "item_recognition"
        var pending = try persistence.pendingJob(accountID: input.userID, capability: capability)
        if let existing = pending,
           existing.inputSHA256 != prepared.sha256,
           existing.jobID == nil {
            try persistence.removePendingJob(accountID: input.userID, capability: capability)
            pending = nil
        }

        let requestID = pending?.requestID ?? "req_item_\(UUID().uuidString.lowercased())"
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

        do {
            let dto = try await execute(
                prepared: prepared,
                requestID: requestID,
                existingAssetID: pending?.assetID,
                existingJobID: pending?.jobID,
                onAsset: { [persistence] assetID in
                    try persistence.savePendingJob(VisionPendingJob(
                        accountID: input.userID,
                        capability: capability,
                        requestID: requestID,
                        jobID: nil,
                        assetID: assetID,
                        inputSHA256: prepared.sha256,
                        status: "uploaded"
                    ))
                },
                onJob: { [persistence] jobID, assetID in
                    try persistence.savePendingJob(VisionPendingJob(
                        accountID: input.userID,
                        capability: capability,
                        requestID: requestID,
                        jobID: jobID,
                        assetID: assetID,
                        inputSHA256: prepared.sha256,
                        status: "queued"
                    ))
                }
            )
            try persistence.removePendingJob(accountID: input.userID, capability: capability)
            return try Self.map(dto: dto, previewImage: input.image, source: "remote_provider")
        } catch let error as VisionAPIError {
            if error == .providerUnavailable || error == .cancelled {
                try? persistence.removePendingJob(accountID: input.userID, capability: capability)
            }
            throw error
        }
    }

    func execute(
        prepared: PreparedVisionImage,
        requestID: String,
        existingAssetID: String?,
        existingJobID: String?,
        onAsset: @escaping (String) throws -> Void,
        onJob: @escaping (String, String) throws -> Void
    ) async throws -> ItemRecognitionResultDTO {
        var assetID = existingAssetID
        if assetID == nil {
            let asset = try await mediaRepository.upload(prepared, requestID: requestID) { _ in }
            assetID = asset.assetId
            try onAsset(asset.assetId)
        }
        guard let assetID else { throw VisionAPIError.uploadFailed }

        var jobID = existingJobID
        if jobID == nil {
            let ticket: AIJobTicketDTO = try await client.sendFlexible(
                path: "/v1/vision/item-recognition-jobs",
                body: CreateItemRecognitionJobRequest(
                    requestId: requestID,
                    assetId: assetID,
                    recognitionScope: RecognitionScopeDTO(
                        allowedCategories: ["eyeshadow_palette", "eyeliner", "makeup_brush"],
                        maxItems: 3
                    )
                ),
                requestID: requestID
            )
            jobID = ticket.jobId
            try onJob(ticket.jobId, assetID)
        }
        guard let jobID else { throw VisionAPIError.jobNotFound }
        return try await poller.poll(
            jobID: jobID,
            fetch: { [jobs] in try await jobs.job(id: $0) }
        )
    }

    static func map(
        dto: ItemRecognitionResultDTO,
        previewImage: UIImage,
        source: String
    ) throws -> CosmeticsRecognitionResult {
        guard let item = dto.items.first,
              let category = CosmeticCategory.from(raw: item.category) else {
            throw CosmeticsRecognitionError.categoryNotRecognized
        }
        let storedPath = try LocalMediaStore.saveImage(
            previewImage,
            bucket: .cosmetics,
            fileName: "recognized_\(UUID().uuidString.lowercased()).jpg"
        )
        let nameParts = [item.brandText, item.productNameText]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let displayName = nameParts.isEmpty ? item.categoryLabelZH : nameParts.joined(separator: " ")
        var tags = item.visibleTexts
        if let shade = item.shadeText, !shade.isEmpty { tags.insert(shade, at: 0) }
        let material = category == .brush ? "化妆刷具" : (item.shadeText ?? "待确认")
        let summary = dto.warnings.first ?? "识别结果待用户确认后加入陈列柜"

        return CosmeticsRecognitionResult(
            displayName: displayName,
            category: category.rawValue,
            tags: Array(tags.prefix(6)),
            colorHexes: item.colors.map(\.hex),
            material: material,
            summary: summary,
            previewPath: storedPath,
            recognitionID: nil,
            needsConfirmation: item.needsConfirmation,
            resultSource: source
        )
    }
}

final class DemoItemRecognitionProvider: ItemRecognitionProviding {
    private let context: SessionContext
    private let persistence: DemoVisionRepository

    init(context: SessionContext, persistence: DemoVisionRepository = DemoVisionRepository()) {
        self.context = context
        self.persistence = persistence
    }

    func recognizeItem(_ input: RecognitionInput) async throws -> CosmeticsRecognitionResult {
        let candidateKeys = [
            "demo_eyeshadow_palette_01",
            "demo_eyeliner_01",
            "demo_makeup_brush_01"
        ]
        var matchedAsset: DemoAssetRecord?
        for key in candidateKeys {
            guard let asset = try persistence.asset(key: key),
                  let cachedImage = UIImage(named: asset.localResourceName) else { continue }
            if DemoImageMatcher.isSameImage(input.image, cachedImage) {
                matchedAsset = asset
                break
            }
        }

        guard let asset = matchedAsset else {
            VisionLog.pipeline.info("Demo item cache miss; routing selected image to remote recognition job")
            do {
                let client = try await MainActor.run { try VisionClientFactory.authenticatedClient() }
                return try await RemoteItemRecognitionProvider(client: client).recognizeItem(input)
            } catch {
                throw normalizedVisionError(error)
            }
        }
        let image = input.image
        VisionLog.pipeline.info("Demo item image matched asset=\(asset.key, privacy: .public)")

        if let cached = try persistence.result(
            accountID: context.userId,
            capability: "item_recognition",
            asset: asset
        ) {
            VisionLog.pipeline.info(
                "Demo recognition cache hit asset=\(asset.key, privacy: .public) source=\(cached.source, privacy: .public)"
            )
            let dto = try decode(cached.json)
            return try RemoteItemRecognitionProvider.map(dto: dto, previewImage: image, source: cached.source)
        }

        if let attempt = try persistence.attempt(
            accountID: context.userId,
            capability: "item_recognition",
            asset: asset
        ) {
            if ["failed", "timed_out", "cancelled"].contains(attempt.status) {
                return try fallback(asset: asset, image: image)
            }
            return try await resumeOrFallback(attempt: attempt, asset: asset, image: image)
        }

        guard context.features.allowLiveRecognitionSeed else {
            return try fallback(asset: asset, image: image)
        }

        let requestID = "req_demo_item_\(UUID().uuidString.lowercased())"
        let attempt = try persistence.beginAttempt(
            accountID: context.userId,
            capability: "item_recognition",
            asset: asset,
            requestID: requestID
        )
        return try await resumeOrFallback(attempt: attempt, asset: asset, image: image)
    }

    private func resumeOrFallback(
        attempt: DemoRecognitionAttempt,
        asset: DemoAssetRecord,
        image: UIImage
    ) async throws -> CosmeticsRecognitionResult {
        do {
            let client = try await MainActor.run { try VisionClientFactory.authenticatedClient() }
            let remote = RemoteItemRecognitionProvider(client: client, persistence: persistence)
            let prepared = try PreparedVisionImage(image: image, fileName: "\(asset.key).jpg")
            let dto = try await remote.execute(
                prepared: prepared,
                requestID: attempt.requestID,
                existingAssetID: asset.remoteAssetID,
                existingJobID: attempt.jobID,
                onAsset: { [persistence] assetID in
                    try persistence.updateRemoteAssetID(assetID, assetKey: asset.key)
                    try persistence.markAttempt(id: attempt.id, status: "uploaded")
                },
                onJob: { [persistence] jobID, _ in
                    // 任务创建后立即落盘；App 中断后只恢复该 job_id。
                    try persistence.markAttempt(id: attempt.id, status: "queued", jobID: jobID)
                }
            )
            var cachedDTO = dto
            cachedDTO.resultSource = "demo_qwen_cache"
            cachedDTO.schemaVersion = DemoVisionRepository.schemaVersion
            let json = String(decoding: try JSONEncoder.visionEncoder.encode(cachedDTO), as: UTF8.self)
            try persistence.saveResult(
                accountID: context.userId,
                capability: "item_recognition",
                asset: asset,
                source: "demo_qwen_cache",
                json: json,
                providerName: "qwen",
                modelID: DemoVisionRepository.modelVersion
            )
            try persistence.markAttempt(id: attempt.id, status: "succeeded")
            return try RemoteItemRecognitionProvider.map(
                dto: cachedDTO,
                previewImage: image,
                source: "demo_qwen_cache"
            )
        } catch {
            let status = (error as? VisionAPIError) == .jobTimedOut ? "timed_out" : "failed"
            let errorCode = stableVisionErrorCode(error)
            try? persistence.markAttempt(
                id: attempt.id,
                status: status,
                errorCode: errorCode
            )
            VisionLog.pipeline.error(
                "Demo recognition fallback asset=\(asset.key, privacy: .public) code=\(errorCode, privacy: .public)"
            )
            return try fallback(asset: asset, image: image)
        }
    }

    private func fallback(asset: DemoAssetRecord, image: UIImage) throws -> CosmeticsRecognitionResult {
        let dataAssetName: String
        switch asset.key {
        case "demo_eyeliner_01": dataAssetName = "DemoEyelinerSeed"
        case "demo_makeup_brush_01": dataAssetName = "DemoMakeupBrushSeed"
        default: dataAssetName = "DemoEyeshadowSeed"
        }
        guard let data = NSDataAsset(name: dataAssetName)?.data else {
            throw VisionAPIError.resultInvalid
        }
        var dto = try JSONDecoder().decode(ItemRecognitionResultDTO.self, from: data)
        dto.resultSource = "demo_fallback"
        dto.schemaVersion = DemoVisionRepository.schemaVersion
        if !dto.warnings.contains("当前展示预置演示结果") {
            dto.warnings.append("当前展示预置演示结果")
        }
        let json = String(decoding: try JSONEncoder.visionEncoder.encode(dto), as: UTF8.self)
        try persistence.saveResult(
            accountID: context.userId,
            capability: "item_recognition",
            asset: asset,
            source: "demo_fallback",
            json: json
        )
        return try RemoteItemRecognitionProvider.map(dto: dto, previewImage: image, source: "demo_fallback")
    }

    private func decode(_ json: String) throws -> ItemRecognitionResultDTO {
        guard let data = json.data(using: .utf8) else { throw VisionAPIError.resultInvalid }
        return try JSONDecoder().decode(ItemRecognitionResultDTO.self, from: data)
    }

}

final class AccountAwareItemRecognitionProvider: ItemRecognitionProviding {
    func recognizeItem(_ input: RecognitionInput) async throws -> CosmeticsRecognitionResult {
        let context = await MainActor.run { SessionManager.shared.context }
        guard let context else { throw VisionAPIError.unauthorized }
        if context.accountMode == .demo, context.features.useDemoAssets {
            VisionLog.pipeline.info("Item recognition route=demo")
            return try await DemoItemRecognitionProvider(context: context).recognizeItem(input)
        }
        VisionLog.pipeline.info("Item recognition route=standard")
        do {
            let client = try await MainActor.run { try VisionClientFactory.authenticatedClient() }
            return try await RemoteItemRecognitionProvider(client: client).recognizeItem(input)
        } catch {
            throw normalizedVisionError(error)
        }
    }
}

final class AccountAwareCosmeticsRecognitionService: CosmeticsRecognitionServicing {
    private let provider: ItemRecognitionProviding

    init(provider: ItemRecognitionProviding = AccountAwareItemRecognitionProvider()) {
        self.provider = provider
    }

    func recognize(image: UIImage, categoryHint: String?) async throws -> CosmeticsRecognitionResult {
        let userID = await MainActor.run { SessionManager.shared.context?.userId }
        guard let userID else { throw VisionAPIError.unauthorized }
        return try await provider.recognizeItem(RecognitionInput(
            image: image,
            userID: userID,
            categoryHint: categoryHint.flatMap(CosmeticCategory.from(raw:))
        ))
    }
}
