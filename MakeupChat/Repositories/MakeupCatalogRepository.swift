import Foundation
import SQLite3

/// 兼容层：旧代码可继续引用，内部转发到拆分后的 Repository
final class MakeupCatalogRepository {
    private let eyeStyles: EyeStyleRepository
    private let cosmetics: CosmeticsRepository

    init(
        eyeStyles: EyeStyleRepository = EyeStyleRepository(),
        cosmetics: CosmeticsRepository = CosmeticsRepository()
    ) {
        self.eyeStyles = eyeStyles
        self.cosmetics = cosmetics
    }

    func eyeStyle(for scene: String) throws -> EyeStyle? {
        try eyeStyles.fetch(scene: scene)
    }

    func cosmeticTip() throws -> String? {
        try cosmetics.brushTip()
    }

    func insertScannedItem(userId: String, category: String, previewPath: String) throws {
        try cosmetics.insertScanned(userId: userId, category: category, previewPath: previewPath)
    }
}
