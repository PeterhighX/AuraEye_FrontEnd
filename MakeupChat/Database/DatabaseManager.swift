import Foundation
import SQLite3

final class DatabaseManager {
    static let shared = DatabaseManager()

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.makeup.chat.database", qos: .userInitiated)

    private init() {
        openDatabase()
        migrate()
        seedIfNeeded()
        resetForFreshLaunch()
    }

    deinit {
        if db != nil {
            sqlite3_close(db)
        }
    }

    func perform<T>(_ work: (OpaquePointer) throws -> T) throws -> T {
        try queue.sync {
            guard let db else {
                throw DatabaseError.notOpen
            }
            return try work(db)
        }
    }

    private func openDatabase() {
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("makeup_chat.sqlite")

        if sqlite3_open(url.path, &db) != SQLITE_OK {
            db = nil
        }
    }

    private func migrate() {
        guard let db else { return }
        for sql in Schema.migrations {
            var error: UnsafeMutablePointer<CChar>?
            if sqlite3_exec(db, sql, nil, nil, &error) != SQLITE_OK {
                if let error {
                    sqlite3_free(error)
                }
            }
        }
        ensureColumn("user_id", definition: "TEXT", in: "cosmetics", database: db)
        ensureColumn("preview_asset", definition: "TEXT", in: "cosmetics", database: db)
        ensureColumn("preview_path", definition: "TEXT", in: "cosmetics", database: db)
        ensureColumn("scanned_at", definition: "REAL", in: "cosmetics", database: db)
        MediaPathMigrator.migrateIfNeeded(in: db)
    }

    /// SQLite 不支持所有版本通用的 `ADD COLUMN IF NOT EXISTS`，先读取表结构再迁移。
    private func ensureColumn(
        _ column: String,
        definition: String,
        in table: String,
        database: OpaquePointer
    ) {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(database, "PRAGMA table_info(\(table));", -1, &statement, nil) == SQLITE_OK else {
            return
        }

        while sqlite3_step(statement) == SQLITE_ROW {
            guard let name = sqlite3_column_text(statement, 1) else { continue }
            if String(cString: name) == column {
                return
            }
        }

        _ = sqlite3_exec(
            database,
            "ALTER TABLE \(table) ADD COLUMN \(column) \(definition);",
            nil,
            nil,
            nil
        )
    }

    private func seedIfNeeded() {
        guard let db else { return }
        let count = scalarInt(db, sql: "SELECT COUNT(*) FROM users;") ?? 0
        guard count == 0 else { return }

        DatabaseSeeder.seed(into: db)
    }

    /// 当前产品规则：每次 App 进程重新启动都视为首次使用。
    /// 保留系统参考数据（如眼型库），清空所有用户产生的记录。
    private func resetForFreshLaunch() {
        guard let db else { return }

        let sql = """
        BEGIN IMMEDIATE;
        DELETE FROM chat_messages;
        DELETE FROM onboarding_steps;
        DELETE FROM cosmetics;
        UPDATE users SET
            display_name = 'Mrs.Zhang',
            status = '开心',
            credits = 50,
            user_file = NULL,
            user_portrait = NULL,
            user_update_photo = NULL,
            eye_preview = NULL,
            eye_steps = NULL,
            updated_at = strftime('%s', 'now');
        COMMIT;
        """

        var error: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &error) != SQLITE_OK {
            _ = sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            if let error {
                sqlite3_free(error)
            }
            return
        }

        LocalMediaStore.clearAllUserGeneratedMedia()
    }

    private func scalarInt(_ db: OpaquePointer, sql: String) -> Int? {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return Int(sqlite3_column_int(statement, 0))
    }
}

enum DatabaseError: Error {
    case notOpen
    case prepareFailed
    case executionFailed
}
