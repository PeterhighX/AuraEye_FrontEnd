import Foundation
import UIKit
import Vision

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
        resultSource: String = "local"
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

final class CosmeticsRecognitionService: CosmeticsRecognitionServicing {
    func recognize(input: VisionImageInput, categoryHint: String?) async throws -> CosmeticsRecognitionResult {
        let image = input.image
        // TODO(Qwen): 上传原图 → 千问识别真实品类、名称、材质、色系与色值。
        // 当前先使用 Apple Vision 本地识别；点击入口绝不能覆盖识别品类。
        try await Task.sleep(for: .milliseconds(600))

        let category = recognizeCategory(in: image)
            ?? categoryHint.flatMap { CosmeticCategory.from(raw: $0) }
            ?? .eyeshadow
        let normalizedCategory = category.rawValue
        let previewImage: UIImage
        let displayName: String
        let tags: [String]
        let colors: [String]
        let material: String
        let summary: String

        if normalizedCategory == CosmeticCategory.eyeshadow.rawValue {
            // 陈列柜始终保存本次拍摄/相册选择的真实图片。
            previewImage = image
            displayName = "某牌 九色眼影盘"
            tags = ["九色眼影", "日常大地色"]
            colors = ["#E8D6C3", "#CBA98E", "#A67C63", "#765746", "#D8C3B4"]
            material = "细腻粉质"
            summary = "九色组合，适合日常眼妆"
        } else {
            previewImage = image
            displayName = "\(normalizedCategory)产品"
            tags = ["待识别"]
            colors = []
            material = normalizedCategory == CosmeticCategory.eyeliner.rawValue
                ? "顺滑笔芯"
                : "柔软刷毛"
            summary = normalizedCategory == CosmeticCategory.eyeliner.rawValue
                ? "便于勾勒自然眼线"
                : "适合取粉与自然晕染"
        }

        let storedPath = try LocalMediaStore.saveImage(
            previewImage,
            bucket: .cosmetics,
            fileName: "cosmetic_\(UUID().uuidString.lowercased()).jpg"
        )

        return CosmeticsRecognitionResult(
            displayName: displayName,
            category: normalizedCategory,
            tags: tags,
            colorHexes: colors,
            material: material,
            summary: summary,
            previewPath: storedPath
        )
    }

    private func recognizeCategory(in image: UIImage) -> CosmeticCategory? {
        guard let cgImage = image.cgImage else { return nil }

        let classificationRequest = VNClassifyImageRequest()
        let rectangleRequest = VNDetectRectanglesRequest()
        rectangleRequest.maximumObservations = 20
        rectangleRequest.minimumConfidence = 0.35
        rectangleRequest.minimumAspectRatio = 0.65
        rectangleRequest.maximumAspectRatio = 1
        rectangleRequest.minimumSize = 0.045

        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .fast
        textRequest.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: CGImagePropertyOrientation(image.imageOrientation),
            options: [:]
        )

        do {
            try handler.perform([
                classificationRequest,
                rectangleRequest,
                textRequest
            ])
        } catch {
            return nil
        }

        let identifiers = (classificationRequest.results ?? [])
            .filter { $0.confidence >= 0.02 }
            .prefix(30)
            .map { $0.identifier.lowercased() }

        if let category = Self.category(from: identifiers) {
            return category
        }

        let recognizedText = (textRequest.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string.lowercased() }
            .joined(separator: " ")

        if Self.containsEyeshadowText(recognizedText) {
            return .eyeshadow
        }

        // 眼影盘常见为 4～12 个规则、相邻的方形色块。通用图像分类器有时只会
        // 返回 “container / tray”，因此额外用盘格结构确认，保证九色眼影盘可识别。
        let colorPanCount = (rectangleRequest.results ?? []).filter { observation in
            let box = observation.boundingBox
            let aspectRatio = box.width / max(box.height, 0.001)
            return (0.68...1.0).contains(aspectRatio)
                && box.width < 0.38
                && box.height < 0.38
        }.count

        if colorPanCount >= 4 {
            return .eyeshadow
        }

        return nil
    }

    /// 模型返回的标签决定最终分栏，点击的是哪一个“添加”按钮不会覆盖这里。
    private static func category(from identifiers: [String]) -> CosmeticCategory? {
        let labels = identifiers.joined(separator: " ")

        if labels.contains("eyeliner") || labels.contains("eye liner") {
            return .eyeliner
        }

        if labels.contains("makeup brush")
            || labels.contains("cosmetic brush")
            || labels.contains("paintbrush")
            || labels.contains("brush") {
            return .brush
        }

        if labels.contains("eyeshadow")
            || labels.contains("eye shadow")
            || labels.contains("makeup palette")
            || labels.contains("cosmetic palette")
            || labels.contains("cosmetics")
            || labels.contains("face powder")
            || labels.contains("pressed powder")
            || labels.contains("compact")
            || labels.contains("palette") {
            return .eyeshadow
        }

        return nil
    }

    private static func containsEyeshadowText(_ text: String) -> Bool {
        [
            "eyeshadow",
            "eye shadow",
            "shadow palette",
            "color palette",
            "9 colors",
            "nine colors",
            "dasique",
            "chic",
            "眼影"
        ].contains { text.contains($0) }
    }

}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
