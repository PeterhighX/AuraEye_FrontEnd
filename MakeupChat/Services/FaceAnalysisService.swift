import Foundation
import UIKit

/// 面部分析由 AuraEye Vision Job 完成；肖像另走受保护的后端资产接口。
protocol FaceAnalysisServicing {
    func analyze(input: VisionImageInput, userId: String) async throws -> FaceAnalysisResult
}

extension FaceAnalysisServicing {
    func analyze(image: UIImage, userId: String) async throws -> FaceAnalysisResult {
        try await analyze(input: VisionImageInput(image: image), userId: userId)
    }
}

struct FaceAnalysisResult {
    /// 当前上传照片的本机缓存，仅供用户再次明确发起分析时使用。
    let portraitPath: String
    let profileJSON: String
}

enum FaceAnalysisError: LocalizedError {
    case personSegmentationFailed

    var errorDescription: String? {
        "人物肖像处理暂时中断，请重试。"
    }
}
