import Foundation
import SQLite3

/// 将历史绝对路径批量改写为 `media/...` 相对路径
enum MediaPathMigrator {
    static func migrateIfNeeded(in db: OpaquePointer) {
        migrateUsers(db)
        migrateCosmetics(db)
        migrateOnboarding(db)
    }

    private static func migrateUsers(_ db: OpaquePointer) {
        for column in ["user_portrait", "user_update_photo", "eye_preview"] {
            rewriteColumn(db, table: "users", column: column, idColumn: "user_id")
        }
    }

    private static func migrateCosmetics(_ db: OpaquePointer) {
        rewriteColumn(db, table: "cosmetics", column: "preview_path", idColumn: "sku")
    }

    private static func migrateOnboarding(_ db: OpaquePointer) {
        rewriteColumn(db, table: "onboarding_steps", column: "preview_path", idColumn: "id")
    }

    private static func rewriteColumn(
        _ db: OpaquePointer,
        table: String,
        column: String,
        idColumn: String
    ) {
        let selectSQL = "SELECT \(idColumn), \(column) FROM \(table) WHERE \(column) IS NOT NULL;"
        var selectStmt: OpaquePointer?
        defer { sqlite3_finalize(selectStmt) }
        guard sqlite3_prepare_v2(db, selectSQL, -1, &selectStmt, nil) == SQLITE_OK else { return }

        var updates: [(String, String)] = []
        while sqlite3_step(selectStmt) == SQLITE_ROW {
            guard
                let idC = sqlite3_column_text(selectStmt, 0),
                let pathC = sqlite3_column_text(selectStmt, 1)
            else { continue }

            let id = String(cString: idC)
            let oldPath = String(cString: pathC)
            guard let normalized = LocalMediaStore.normalizeForStorage(oldPath),
                  normalized != oldPath,
                  normalized.hasPrefix("media/")
            else { continue }

            updates.append((id, normalized))
        }

        let updateSQL = "UPDATE \(table) SET \(column) = ? WHERE \(idColumn) = ?;"
        for (id, newPath) in updates {
            var updateStmt: OpaquePointer?
            defer { sqlite3_finalize(updateStmt) }
            guard sqlite3_prepare_v2(db, updateSQL, -1, &updateStmt, nil) == SQLITE_OK else { continue }
            sqlite3_bind_text(updateStmt, 1, newPath, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(updateStmt, 2, id, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            _ = sqlite3_step(updateStmt)
        }
    }
}
