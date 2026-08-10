import Foundation
import UIKit

struct RecognitionInput {
    let image: UIImage
    let originalData: Data?
    let contentType: String?
    let userID: String
    let categoryHint: CosmeticCategory?

    var visionInput: VisionImageInput {
        if let originalData, let contentType,
           let input = try? VisionImageInput(photoData: originalData, contentType: contentType) {
            return input
        }
        return VisionImageInput(image: image)
    }
}

struct RecognitionColorDTO: Codable, Equatable, Sendable {
    let hex: String
    let proportion: Double?

    private enum CodingKeys: String, CodingKey {
        case hex, proportion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let hex = try? container.decode(String.self) {
            self.hex = hex
            proportion = nil
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
    let warnings: [String]
    let knowledgeKeys: [String]

    enum CodingKeys: String, CodingKey {
        case recognitionLevel = "recognition_level"
        case items, warnings
        case knowledgeKeys = "knowledge_keys"
    }
}

protocol ItemRecognitionProviding {
    func recognizeItem(_ input: RecognitionInput) async throws -> CosmeticsRecognitionResult
}

final class UnifiedItemRecognitionProvider: ItemRecognitionProviding {
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

    func recognizeItem(_ input: RecognitionInput) async throws -> CosmeticsRecognitionResult {
        let capability = VisionCapability.itemRecognition
        let pending = try persistence.pendingJob(accountID: input.userID, capability: capability)
        let requestID = pending?.requestID ?? "req_item_\(UUID().uuidString.lowercased())"
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
                let options = VisionJobOptions.itemRecognition(ItemRecognitionJobOptions(
                    allowedCategories: ["makeup_brush", "eyeliner", "eyeshadow_palette"],
                    maxItems: 3
                ))
                let response = try await service.create(
                    input: input.visionInput,
                    capability: capability,
                    options: options,
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

            let dto: ItemRecognitionResultDTO = try await poller.poll(
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
            return try Self.map(dto: dto, previewImage: input.image)
        } catch let error as VisionAPIError {
            if [.providerUnavailable, .cancelled, .demoFixtureNotRecognized,
                .demoFixtureMismatch, .demoCacheNotReady, .payloadTooLarge,
                .unsupportedMediaType].contains(error) {
                try? persistence.removePendingJob(accountID: input.userID, capability: capability)
            }
            throw error
        }
    }

    static func map(
        dto: ItemRecognitionResultDTO,
        previewImage: UIImage
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
            resultSource: "vision_job"
        )
    }
}

final class AccountAwareItemRecognitionProvider: ItemRecognitionProviding {
    func recognizeItem(_ input: RecognitionInput) async throws -> CosmeticsRecognitionResult {
        guard await MainActor.run(body: { SessionManager.shared.context != nil }) else {
            throw VisionAPIError.unauthorized
        }
        do {
            let client = try await MainActor.run { try VisionClientFactory.authenticatedClient() }
            return try await UnifiedItemRecognitionProvider(client: client).recognizeItem(input)
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

    func recognize(input: VisionImageInput, categoryHint: String?) async throws -> CosmeticsRecognitionResult {
        let userID = await MainActor.run { SessionManager.shared.context?.userId }
        guard let userID else { throw VisionAPIError.unauthorized }
        return try await provider.recognizeItem(RecognitionInput(
            image: input.image,
            originalData: input.originalData,
            contentType: input.contentType,
            userID: userID,
            categoryHint: categoryHint.flatMap(CosmeticCategory.from(raw:))
        ))
    }
}
