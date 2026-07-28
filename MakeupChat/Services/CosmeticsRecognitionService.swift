import Foundation
import UIKit

/// 化妆品拍摄识别 — 本地占位，等阿里云后台接入后替换实现
struct CosmeticsRecognitionResult {
    let displayName: String
    let category: String
    let tags: [String]
    let colorHexes: [String]
    let previewPath: String
}

protocol CosmeticsRecognitionServicing {
    /// `categoryHint` 仅用于本地演示；接入识别模型后以模型返回的 category 为准。
    func recognize(image: UIImage, categoryHint: String?) async throws -> CosmeticsRecognitionResult
}

final class CosmeticsRecognitionService: CosmeticsRecognitionServicing {
    func recognize(image: UIImage, categoryHint: String?) async throws -> CosmeticsRecognitionResult {
        // TODO: 上传图片 → 后台识别品牌 / SKU / 色值 → 写回结构化结果
        try await Task.sleep(for: .milliseconds(600))

        let normalizedCategory = CosmeticCategory.normalize(
            categoryHint ?? CosmeticCategory.eyeshadow.rawValue
        )
        let previewImage: UIImage
        let displayName: String
        let tags: [String]
        let colors: [String]

        if normalizedCategory == CosmeticCategory.eyeshadow.rawValue,
           let officialImage = UIImage(named: "RecognizedEyeshadow") {
            previewImage = officialImage
            displayName = "某牌 九色眼影盘"
            tags = ["九色眼影", "日常大地色"]
            colors = ["#E8D6C3", "#CBA98E", "#A67C63", "#765746", "#D8C3B4"]
        } else {
            previewImage = image
            displayName = "\(normalizedCategory)产品"
            tags = ["待识别"]
            colors = []
        }

        let storedPath = try LocalMediaStore.saveImage(
            previewImage,
            bucket: .cosmetics,
            fileName: "cosmetic_\(Int(Date().timeIntervalSince1970)).jpg"
        )

        return CosmeticsRecognitionResult(
            displayName: displayName,
            category: normalizedCategory,
            tags: tags,
            colorHexes: colors,
            previewPath: storedPath
        )
    }
}
