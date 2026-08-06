import CryptoKit
import Foundation
import SQLite3
import UIKit

enum DemoImageMatcher {
    /// 相册导入可能改变 JPEG 压缩、色彩描述或文件元数据，因此不能比较原始文件字节。
    /// 这里比较标准化像素的差异哈希、平均颜色和宽高比，只命中同一张未裁剪图片。
    static func isSameImage(_ lhs: UIImage, _ rhs: UIImage) -> Bool {
        guard let left = fingerprint(lhs), let right = fingerprint(rhs) else { return false }
        let hammingDistance = (left.differenceHash ^ right.differenceHash).nonzeroBitCount
        let colorDistance = sqrt(
            pow(left.averageRed - right.averageRed, 2)
                + pow(left.averageGreen - right.averageGreen, 2)
                + pow(left.averageBlue - right.averageBlue, 2)
        )
        let aspectDifference = abs(left.aspectRatio - right.aspectRatio)
            / max(max(left.aspectRatio, right.aspectRatio), 0.001)
        return hammingDistance <= 6 && colorDistance <= 0.10 && aspectDifference <= 0.025
    }

    private struct Fingerprint {
        let differenceHash: UInt64
        let averageRed: Double
        let averageGreen: Double
        let averageBlue: Double
        let aspectRatio: Double
    }

    private static func fingerprint(_ image: UIImage) -> Fingerprint? {
        let normalized = normalizedImage(image)
        guard let cgImage = normalized.cgImage,
              let grayscale = grayscalePixels(cgImage, width: 9, height: 8),
              let colors = rgbaPixels(cgImage, width: 8, height: 8) else { return nil }

        var hash: UInt64 = 0
        var bit: UInt64 = 1
        for row in 0..<8 {
            for column in 0..<8 {
                let left = grayscale[row * 9 + column]
                let right = grayscale[row * 9 + column + 1]
                if left > right { hash |= bit }
                bit <<= 1
            }
        }

        var red = 0.0
        var green = 0.0
        var blue = 0.0
        for index in stride(from: 0, to: colors.count, by: 4) {
            red += Double(colors[index]) / 255
            green += Double(colors[index + 1]) / 255
            blue += Double(colors[index + 2]) / 255
        }
        let pixelCount = 64.0
        return Fingerprint(
            differenceHash: hash,
            averageRed: red / pixelCount,
            averageGreen: green / pixelCount,
            averageBlue: blue / pixelCount,
            aspectRatio: Double(cgImage.width) / Double(max(cgImage.height, 1))
        )
    }

    private static func normalizedImage(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private static func grayscalePixels(_ image: CGImage, width: Int, height: Int) -> [UInt8]? {
        var pixels = [UInt8](repeating: 0, count: width * height)
        let rendered = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let address = buffer.baseAddress,
                  let context = CGContext(
                    data: address,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width,
                    space: CGColorSpaceCreateDeviceGray(),
                    bitmapInfo: CGImageAlphaInfo.none.rawValue
                  ) else { return false }
            // 相册可能把透明 PNG/SVG 展平为白底 JPEG；统一以白底合成后再比较。
            context.setFillColor(gray: 1, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return rendered ? pixels : nil
    }

    private static func rgbaPixels(_ image: CGImage, width: Int, height: Int) -> [UInt8]? {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let rendered = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let address = buffer.baseAddress,
                  let context = CGContext(
                    data: address,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else { return false }
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return rendered ? pixels : nil
    }
}

struct DemoAssetRecord: Sendable {
    let key: String
    let type: String
    let localResourceName: String
    let sha256: String
    let datasetVersion: String
    let remoteAssetID: String?
}

struct DemoRecognitionAttempt: Sendable {
    let id: String
    let accountID: String
    let assetKey: String
    let requestID: String
    let jobID: String?
    let status: String
    let assetSHA256: String
    let schemaVersion: String
    let modelVersion: String
}

struct StoredVisionResult: Sendable {
    let json: String
    let source: String
}

struct VisionPendingJob: Sendable {
    let accountID: String
    let capability: String
    let requestID: String
    let jobID: String?
    let assetID: String?
    let inputSHA256: String
    let status: String
}

enum DemoDataSeeder {
    static let datasetVersion = "demo-assets-v1"

    private static let assets: [(key: String, type: String, resource: String)] = [
        ("demo_portrait_01", "portrait", "AvatarUserCutout"),
        ("demo_eyeshadow_palette_01", "cosmetic", "RecognizedEyeshadow"),
        ("demo_eyeliner_01", "cosmetic", "EyelinerProductIcon"),
        ("demo_makeup_brush_01", "tool", "PracticeToolIcon")
    ]

    static func seedIfNeeded(into db: OpaquePointer) {
        let now = ISO8601DateFormatter().string(from: Date())
        for asset in assets {
            let sha = imageSHA256(named: asset.resource)
            if let previous = metadata(for: asset.key, in: db),
               previous.sha != sha || previous.dataset != datasetVersion {
                execute(
                    db,
                    sql: "DELETE FROM demo_recognition_attempts WHERE demo_asset_key = ?;",
                    values: [asset.key]
                )
                execute(
                    db,
                    sql: "DELETE FROM demo_results WHERE demo_asset_key = ?;",
                    values: [asset.key]
                )
            }
            execute(db, sql: """
            INSERT INTO demo_assets (
                demo_asset_key, asset_type, local_resource_name, asset_sha256,
                dataset_version, remote_asset_id, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, NULL, ?, ?)
            ON CONFLICT(demo_asset_key) DO UPDATE SET
                asset_type = excluded.asset_type,
                local_resource_name = excluded.local_resource_name,
                asset_sha256 = excluded.asset_sha256,
                dataset_version = excluded.dataset_version,
                updated_at = excluded.updated_at;
            """, values: [asset.key, asset.type, asset.resource, sha, datasetVersion, now, now])
        }
    }

    private static func imageSHA256(named name: String) -> String {
        let data = UIImage(named: name)?.pngData() ?? Data(name.utf8)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func metadata(for key: String, in db: OpaquePointer) -> (sha: String, dataset: String)? {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(
            db,
            "SELECT asset_sha256, dataset_version FROM demo_assets WHERE demo_asset_key = ? LIMIT 1;",
            -1,
            &statement,
            nil
        ) == SQLITE_OK else { return nil }
        sqlite3_bind_text(statement, 1, key, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        guard sqlite3_step(statement) == SQLITE_ROW,
              let sha = sqlite3_column_text(statement, 0),
              let dataset = sqlite3_column_text(statement, 1) else { return nil }
        return (String(cString: sha), String(cString: dataset))
    }

    private static func execute(_ db: OpaquePointer, sql: String, values: [String]) {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }
        for (index, value) in values.enumerated() {
            sqlite3_bind_text(
                statement,
                Int32(index + 1),
                value,
                -1,
                unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            )
        }
        _ = sqlite3_step(statement)
    }
}

final class DemoVisionRepository {
    static let schemaVersion = "1.0"
    static let modelVersion = "qwen-vision-v1"

    private let db: DatabaseManager

    init(db: DatabaseManager = .shared) {
        self.db = db
    }

    func asset(key: String) throws -> DemoAssetRecord? {
        try db.perform { db in
            let sql = """
            SELECT demo_asset_key, asset_type, local_resource_name, asset_sha256,
                   dataset_version, remote_asset_id
            FROM demo_assets WHERE demo_asset_key = ? LIMIT 1;
            """
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed
            }
            bind(key, to: statement, at: 1)
            guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
            return DemoAssetRecord(
                key: text(statement, 0) ?? "",
                type: text(statement, 1) ?? "",
                localResourceName: text(statement, 2) ?? "",
                sha256: text(statement, 3) ?? "",
                datasetVersion: text(statement, 4) ?? "",
                remoteAssetID: text(statement, 5)
            )
        }
    }

    func updateRemoteAssetID(_ remoteAssetID: String, assetKey: String) throws {
        try execute(
            "UPDATE demo_assets SET remote_asset_id = ?, updated_at = ? WHERE demo_asset_key = ?;",
            [remoteAssetID, now(), assetKey]
        )
    }

    func attempt(accountID: String, capability: String, asset: DemoAssetRecord) throws -> DemoRecognitionAttempt? {
        try db.perform { db in
            let sql = """
            SELECT id, account_id, demo_asset_key, request_id, job_id, status,
                   asset_sha256, schema_version, model_version
            FROM demo_recognition_attempts
            WHERE account_id = ? AND capability = ? AND demo_asset_key = ?
              AND asset_sha256 = ? AND schema_version = ? AND model_version = ?
            LIMIT 1;
            """
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed
            }
            [accountID, capability, asset.key, asset.sha256, Self.schemaVersion, Self.modelVersion]
                .enumerated()
                .forEach { bind($0.element, to: statement, at: Int32($0.offset + 1)) }
            guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
            return DemoRecognitionAttempt(
                id: text(statement, 0) ?? "",
                accountID: text(statement, 1) ?? "",
                assetKey: text(statement, 2) ?? "",
                requestID: text(statement, 3) ?? "",
                jobID: text(statement, 4),
                status: text(statement, 5) ?? "",
                assetSHA256: text(statement, 6) ?? "",
                schemaVersion: text(statement, 7) ?? "",
                modelVersion: text(statement, 8) ?? ""
            )
        }
    }

    func beginAttempt(
        accountID: String,
        capability: String,
        asset: DemoAssetRecord,
        requestID: String
    ) throws -> DemoRecognitionAttempt {
        let attempt = DemoRecognitionAttempt(
            id: UUID().uuidString.lowercased(),
            accountID: accountID,
            assetKey: asset.key,
            requestID: requestID,
            jobID: nil,
            status: "preparing",
            assetSHA256: asset.sha256,
            schemaVersion: Self.schemaVersion,
            modelVersion: Self.modelVersion
        )
        try execute("""
        INSERT INTO demo_recognition_attempts (
            id, account_id, demo_asset_key, capability, request_id, job_id, status,
            asset_sha256, schema_version, model_version, error_code, started_at, completed_at
        ) VALUES (?, ?, ?, ?, ?, NULL, ?, ?, ?, ?, NULL, ?, NULL);
        """, [
            attempt.id, accountID, asset.key, capability, requestID, attempt.status,
            asset.sha256, Self.schemaVersion, Self.modelVersion, now()
        ])
        return attempt
    }

    func markAttempt(
        id: String,
        status: String,
        jobID: String? = nil,
        errorCode: String? = nil
    ) throws {
        try db.perform { db in
            let sql = """
            UPDATE demo_recognition_attempts
            SET status = ?, job_id = COALESCE(?, job_id), error_code = ?,
                completed_at = CASE WHEN ? IN ('succeeded','failed','timed_out','cancelled')
                                    THEN ? ELSE completed_at END
            WHERE id = ?;
            """
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed
            }
            bind(status, to: statement, at: 1)
            bindOptional(jobID, to: statement, at: 2)
            bindOptional(errorCode, to: statement, at: 3)
            bind(status, to: statement, at: 4)
            bind(now(), to: statement, at: 5)
            bind(id, to: statement, at: 6)
            guard sqlite3_step(statement) == SQLITE_DONE else { throw DatabaseError.executionFailed }
        }
    }

    func result(accountID: String, capability: String, asset: DemoAssetRecord) throws -> StoredVisionResult? {
        try db.perform { db in
            let sql = """
            SELECT result_json, result_source, model_id FROM demo_results
            WHERE account_id = ? AND capability = ? AND demo_asset_key = ?
              AND asset_sha256 = ? AND schema_version = ?
            LIMIT 1;
            """
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed
            }
            [accountID, capability, asset.key, asset.sha256, Self.schemaVersion]
                .enumerated()
                .forEach { bind($0.element, to: statement, at: Int32($0.offset + 1)) }
            guard sqlite3_step(statement) == SQLITE_ROW,
                  let json = text(statement, 0),
                  let source = text(statement, 1) else { return nil }
            if source == "demo_qwen_cache", text(statement, 2) != Self.modelVersion {
                return nil
            }
            return StoredVisionResult(json: json, source: source)
        }
    }

    func saveResult(
        accountID: String,
        capability: String,
        asset: DemoAssetRecord,
        source: String,
        json: String,
        providerName: String? = nil,
        modelID: String? = nil
    ) throws {
        try db.perform { db in
            let sql = """
            INSERT INTO demo_results (
                id, account_id, capability, demo_asset_key, asset_sha256, schema_version,
                provider_name, model_id, result_source, result_json, generated_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(account_id, capability, demo_asset_key, asset_sha256, schema_version)
            DO UPDATE SET provider_name = excluded.provider_name, model_id = excluded.model_id,
                          result_source = excluded.result_source, result_json = excluded.result_json,
                          generated_at = excluded.generated_at, updated_at = excluded.updated_at;
            """
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed
            }
            let values: [String?] = [
                UUID().uuidString.lowercased(), accountID, capability, asset.key, asset.sha256,
                Self.schemaVersion, providerName, modelID, source, json, now(), now()
            ]
            values.enumerated().forEach { bindOptional($0.element, to: statement, at: Int32($0.offset + 1)) }
            guard sqlite3_step(statement) == SQLITE_DONE else { throw DatabaseError.executionFailed }
        }
    }

    func pendingJob(accountID: String, capability: String) throws -> VisionPendingJob? {
        try db.perform { db in
            let sql = """
            SELECT account_id, capability, request_id, job_id, asset_id, input_sha256, status
            FROM vision_pending_jobs WHERE account_id = ? AND capability = ? LIMIT 1;
            """
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed
            }
            bind(accountID, to: statement, at: 1)
            bind(capability, to: statement, at: 2)
            guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
            return VisionPendingJob(
                accountID: text(statement, 0) ?? "",
                capability: text(statement, 1) ?? "",
                requestID: text(statement, 2) ?? "",
                jobID: text(statement, 3),
                assetID: text(statement, 4),
                inputSHA256: text(statement, 5) ?? "",
                status: text(statement, 6) ?? ""
            )
        }
    }

    func savePendingJob(_ job: VisionPendingJob) throws {
        try db.perform { db in
            let sql = """
            INSERT INTO vision_pending_jobs (
                account_id, capability, request_id, job_id, asset_id,
                input_sha256, status, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(account_id, capability) DO UPDATE SET
                request_id = excluded.request_id, job_id = excluded.job_id,
                asset_id = excluded.asset_id, input_sha256 = excluded.input_sha256,
                status = excluded.status, updated_at = excluded.updated_at;
            """
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed
            }
            let timestamp = now()
            let values: [String?] = [
                job.accountID, job.capability, job.requestID, job.jobID, job.assetID,
                job.inputSHA256, job.status, timestamp, timestamp
            ]
            values.enumerated().forEach { bindOptional($0.element, to: statement, at: Int32($0.offset + 1)) }
            guard sqlite3_step(statement) == SQLITE_DONE else { throw DatabaseError.executionFailed }
        }
    }

    func removePendingJob(accountID: String, capability: String) throws {
        try execute(
            "DELETE FROM vision_pending_jobs WHERE account_id = ? AND capability = ?;",
            [accountID, capability]
        )
    }

    private func execute(_ sql: String, _ values: [String]) throws {
        try db.perform { db in
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed
            }
            values.enumerated().forEach { bind($0.element, to: statement, at: Int32($0.offset + 1)) }
            guard sqlite3_step(statement) == SQLITE_DONE else { throw DatabaseError.executionFailed }
        }
    }

    private func now() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}

private func bind(_ value: String, to statement: OpaquePointer?, at index: Int32) {
    sqlite3_bind_text(statement, index, value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
}

private func bindOptional(_ value: String?, to statement: OpaquePointer?, at index: Int32) {
    if let value { bind(value, to: statement, at: index) }
    else { sqlite3_bind_null(statement, index) }
}

private func text(_ statement: OpaquePointer?, _ index: Int32) -> String? {
    guard let value = sqlite3_column_text(statement, index) else { return nil }
    return String(cString: value)
}
