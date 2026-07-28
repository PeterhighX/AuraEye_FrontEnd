import Foundation
import UIKit

/// @deprecated 请使用 `LocalMediaStore`，保留兼容旧调用
enum FaceScanService {
    static func savePortrait(_ image: UIImage) throws -> String {
        try LocalMediaStore.saveImage(image, bucket: .portraits, fileName: "user_portrait_\(timestamp()).jpg")
    }

    static func saveCosmeticScan(_ image: UIImage) throws -> String {
        try LocalMediaStore.saveImage(image, bucket: .cosmetics, fileName: "cosmetic_scan_\(timestamp()).jpg")
    }

    private static func timestamp() -> Int {
        Int(Date().timeIntervalSince1970)
    }
}

enum FaceScanError: Error {
    case encodingFailed
}
