import Foundation
import UIKit

/// 本地媒体文件桶 — 与 `后端数据库.md` 字段对应
enum MediaBucket: String {
    /// `users.user_portrait` 肖像照（自拍）
    case portraits
    /// `users.user_update_photo` 用户上传图
    case uploads
    /// `users.eye_preview` 眼型/妆容预览
    case eyePreviews
    /// `cosmetics.preview_path` 化妆品扫描图
    case cosmetics
    /// `chat_messages.image_path` 聊天图片
    case chat
    /// 第一次使用 · 妆容生成步骤预览
    case makeupPreviews
}

/// 统一管理本地文件：磁盘存文件，SQLite 只存相对路径 `media/{bucket}/{file}`
enum LocalMediaStore {
    private static let rootFolder = "media"

    // MARK: - 根目录

    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var mediaRootURL: URL {
        let url = documentsDirectory.appendingPathComponent(rootFolder, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: - 写入（返回相对路径，供 SQLite 存储）

    @discardableResult
    static func saveImage(
        _ image: UIImage,
        bucket: MediaBucket,
        fileName: String? = nil,
        quality: CGFloat = 0.85
    ) throws -> String {
        let name = fileName ?? "\(bucket.rawValue)_\(Int(Date().timeIntervalSince1970)).jpg"
        let url = try fileURL(bucket: bucket, fileName: name)

        guard let data = image.jpegData(compressionQuality: quality) else {
            throw LocalMediaError.encodingFailed
        }
        try data.write(to: url, options: .atomic)
        return relativePath(bucket: bucket, fileName: name)
    }

    @discardableResult
    static func saveText(_ text: String, bucket: MediaBucket, fileName: String) throws -> String {
        let url = try fileURL(bucket: bucket, fileName: fileName)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return relativePath(bucket: bucket, fileName: fileName)
    }

    /// 将 Asset Catalog 图片落盘（演示数据种子用）
    @discardableResult
    static func saveBundledImage(
        named assetName: String,
        bucket: MediaBucket,
        fileName: String
    ) throws -> String {
        guard let image = UIImage(named: assetName) else {
            throw LocalMediaError.assetNotFound(assetName)
        }
        return try saveImage(image, bucket: bucket, fileName: fileName)
    }

    // MARK: - 读取

    static func fileURL(forStoredPath storedPath: String?) -> URL? {
        guard let storedPath, !storedPath.isEmpty else { return nil }

        if storedPath.hasPrefix("\(rootFolder)/") {
            return documentsDirectory.appendingPathComponent(storedPath)
        }

        // 兼容旧版绝对路径
        if storedPath.hasPrefix("/") {
            return URL(fileURLWithPath: storedPath)
        }

        return documentsDirectory.appendingPathComponent(storedPath)
    }

    static func loadImage(fromStoredPath storedPath: String?) -> UIImage? {
        guard let url = fileURL(forStoredPath: storedPath) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    static func fileExists(storedPath: String?) -> Bool {
        guard let url = fileURL(forStoredPath: storedPath) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// 将任意历史路径规范为 `media/...` 相对路径
    static func normalizeForStorage(_ path: String?) -> String? {
        guard let path, !path.isEmpty else { return nil }

        if path.hasPrefix("\(rootFolder)/") {
            return path
        }

        let docs = documentsDirectory.path
        if path.hasPrefix(docs) {
            let suffix = String(path.dropFirst(docs.count))
            let trimmed = suffix.hasPrefix("/") ? String(suffix.dropFirst()) : suffix
            if trimmed.hasPrefix("\(rootFolder)/") {
                return trimmed
            }
        }

        // 无法转换的绝对路径原样保留（迁移器后续处理）
        return path
    }

    /// 仅清理 App Documents/media 下由用户产生的内容，不影响 Asset Catalog。
    static func clearAllUserGeneratedMedia() {
        let url = documentsDirectory.appendingPathComponent(rootFolder, isDirectory: true)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Private

    private static func relativePath(bucket: MediaBucket, fileName: String) -> String {
        "\(rootFolder)/\(bucket.rawValue)/\(fileName)"
    }

    private static func fileURL(bucket: MediaBucket, fileName: String) throws -> URL {
        let directory = mediaRootURL.appendingPathComponent(bucket.rawValue, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(fileName)
    }
}

enum LocalMediaError: Error {
    case encodingFailed
    case assetNotFound(String)
}
