import Foundation
import UIKit

/// 面部分析接口边界。
/// 后续接入面部分析大模型时，实现此协议并注入 ViewModel 即可。
protocol FaceAnalysisServicing {
    func analyze(image: UIImage, userId: String) async throws -> FaceAnalysisResult
}

struct FaceAnalysisResult {
    /// 后续由虚拟分身模型返回生成图片；本地阶段使用上传照片作为可视占位。
    let portraitPath: String
    let profileJSON: String
}

/// 当前纯前端阶段的本地模拟实现。
final class LocalFaceAnalysisService: FaceAnalysisServicing {
    func analyze(image: UIImage, userId: String) async throws -> FaceAnalysisResult {
        try await Task.sleep(for: .seconds(2.4))

        let portraitPath = try LocalMediaStore.saveImage(
            image,
            bucket: .portraits,
            fileName: "virtual_avatar_\(userId).jpg"
        )

        let profileJSON = """
        {
          "faceShape": "鹅蛋脸",
          "skinTone": "粉皮（偏白）",
          "eyeShape": "杏眼",
          "recommendedStyle": "清透自然"
        }
        """

        return FaceAnalysisResult(
            portraitPath: portraitPath,
            profileJSON: profileJSON
        )
    }
}
