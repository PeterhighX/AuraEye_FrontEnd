import Foundation
import UIKit

/// 化妆品拍摄识别结果。千问视觉接口后续只需返回这一结构，
/// 陈列柜不会再依赖或展示 SKU。
struct CosmeticsRecognitionResult {
    let displayName: String
    let category: String
    let tags: [String]
    let colorHexes: [String]
    let material: String
    let summary: String
    let previewPath: String
    let recognitionID: String?
    let needsConfirmation: Bool
    let resultSource: String

    init(
        displayName: String,
        category: String,
        tags: [String],
        colorHexes: [String],
        material: String,
        summary: String,
        previewPath: String,
        recognitionID: String? = nil,
        needsConfirmation: Bool = true,
        resultSource: String
    ) {
        self.displayName = displayName
        self.category = category
        self.tags = tags
        self.colorHexes = colorHexes
        self.material = material
        self.summary = summary
        self.previewPath = previewPath
        self.recognitionID = recognitionID
        self.needsConfirmation = needsConfirmation
        self.resultSource = resultSource
    }

    var hasRequiredProductInformation: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && CosmeticCategory.from(raw: category) != nil
            && !previewPath.isEmpty
    }
}

protocol CosmeticsRecognitionServicing {
    /// `categoryHint` 仅作为识别上下文，不能覆盖模型返回的真实品类。
    func recognize(input: VisionImageInput, categoryHint: String?) async throws -> CosmeticsRecognitionResult
}

extension CosmeticsRecognitionServicing {
    func recognize(image: UIImage, categoryHint: String?) async throws -> CosmeticsRecognitionResult {
        try await recognize(input: VisionImageInput(image: image), categoryHint: categoryHint)
    }
}

enum CosmeticsRecognitionError: LocalizedError {
    case categoryNotRecognized
    case incompleteProductInformation

    var errorDescription: String? {
        switch self {
        case .categoryNotRecognized:
            return "未能确认产品属于眼影、眼线或毛刷，请调整角度后重新拍摄。"
        case .incompleteProductInformation:
            return "没有识别到完整的化妆品信息，请重新拍照或选择其他图片。"
        }
    }
}
