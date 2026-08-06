import Foundation
import SQLite3

/// 化妆品库 — 对应 `后端数据库.md` cosmetics
final class CosmeticsRepository {
    private let db: DatabaseManager

    init(db: DatabaseManager = .shared) {
        self.db = db
    }

    func fetchAll(userId: String? = nil) throws -> [CosmeticItem] {
        try db.perform { db in
            let sql: String
            if userId != nil {
                sql = """
                SELECT
                    sku,
                    makeup_cat,
                    makeup_tab,
                    makeup_colors,
                    brush_json,
                    preview_path
                FROM cosmetics
                WHERE user_id = ? OR user_id IS NULL
                ORDER BY scanned_at DESC;
                """
            } else {
                sql = """
                SELECT
                    sku,
                    makeup_cat,
                    makeup_tab,
                    makeup_colors,
                    brush_json,
                    preview_path
                FROM cosmetics
                ORDER BY scanned_at DESC;
                """
            }

            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }

            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed
            }
            if let userId {
                sqlite3_bind_text(statement, 1, userId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            }

            var results: [CosmeticItem] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                results.append(map(statement))
            }
            return results
        }
    }

    /// 首次引导只统计用户本次实际扫描入库的产品，不把系统示例商品算入三类完成条件。
    func fetchUserOwned(userId: String) throws -> [CosmeticItem] {
        try db.perform { db in
            let sql = """
            SELECT sku, makeup_cat, makeup_tab, makeup_colors, brush_json, preview_path
            FROM cosmetics
            WHERE user_id = ?
            ORDER BY scanned_at DESC;
            """
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed
            }
            sqlite3_bind_text(statement, 1, userId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

            var results: [CosmeticItem] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                results.append(map(statement))
            }
            return results
        }
    }

    func insertScanned(
        userId: String,
        category: String,
        previewPath: String,
        tab: String? = nil,
        colorsJSON: String? = nil,
        brushJSON: String? = nil,
        sku: String? = nil
    ) throws {
        try db.perform { db in
            // 同一秒内连续重试也必须能够入库，不能再使用秒级时间戳作为主键。
            let resolvedSKU = sku ?? "scan_\(UUID().uuidString.lowercased())"
            let sql = """
            INSERT INTO cosmetics (sku, user_id, makeup_cat, makeup_tab, makeup_colors, brush_json, preview_path, scanned_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?);
            """
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }

            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed
            }

            let now = Date().timeIntervalSince1970
            sqlite3_bind_text(statement, 1, resolvedSKU, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(statement, 2, userId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(statement, 3, category, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            bindOptionalText(statement, 4, tab)
            bindOptionalText(statement, 5, colorsJSON)
            bindOptionalText(statement, 6, brushJSON)
            sqlite3_bind_text(statement, 7, previewPath, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_double(statement, 8, now)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw DatabaseError.executionFailed
            }
        }
    }

    func insertRecognized(userId: String, result: CosmeticsRecognitionResult) throws {
        let tab: String?
        if result.tags.count > 1,
           let data = try? JSONSerialization.data(withJSONObject: result.tags),
           let json = String(data: data, encoding: .utf8) {
            tab = json
        } else {
            tab = result.tags.first
        }

        let colorsJSON: String?
        if !result.colorHexes.isEmpty,
           let data = try? JSONSerialization.data(withJSONObject: result.colorHexes),
           let json = String(data: data, encoding: .utf8) {
            colorsJSON = json
        } else {
            colorsJSON = nil
        }

        let metadata: [String: String] = [
            "name": result.displayName,
            "material": result.material,
            "summary": result.summary
        ]
        let metadataData = try? JSONSerialization.data(withJSONObject: metadata)
        let brushJSON = metadataData.flatMap { String(data: $0, encoding: .utf8) }

        try insertScanned(
            userId: userId,
            category: result.category,
            previewPath: result.previewPath,
            tab: tab,
            colorsJSON: colorsJSON,
            brushJSON: brushJSON
        )
    }

    func brushTip() throws -> String? {
        try db.perform { db in
            let sql = "SELECT brush_json FROM cosmetics WHERE brush_json IS NOT NULL LIMIT 1;"
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }

            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
            guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
            guard
                let json = columnText(statement, 0),
                let data = json.data(using: .utf8),
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let tip = object["tip"] as? String
            else { return nil }

            return tip
        }
    }

    private func map(_ statement: OpaquePointer?) -> CosmeticItem {
        CosmeticItem(
            sku: columnText(statement, 0) ?? "",
            makeupCategory: columnText(statement, 1) ?? "",
            makeupTab: columnText(statement, 2),
            makeupColorsJSON: columnText(statement, 3),
            brushJSON: columnText(statement, 4),
            previewPath: columnText(statement, 5)
        )
    }

    private func columnText(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        guard let cString = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: cString)
    }

    private func bindOptionalText(_ statement: OpaquePointer?, _ index: Int32, _ value: String?) {
        if let value {
            sqlite3_bind_text(statement, index, value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        } else {
            sqlite3_bind_null(statement, index)
        }
    }
}
