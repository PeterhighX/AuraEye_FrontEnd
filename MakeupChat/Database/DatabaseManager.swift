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
        applyVisionAPIV11Migration(database: db)
        applyUnifiedVisionJobMigration(database: db)
        applyChatHermesMigration(database: db)
        MediaPathMigrator.migrateIfNeeded(in: db)
    }

    /// API v1.1 的显式、可恢复 migration。旧 `request_id` 保留，并复制为
    /// `idempotency_key`，避免升级后把未完成任务当成全新付费动作。
    private func applyVisionAPIV11Migration(database: OpaquePointer) {
        let currentVersion = scalarInt(database, sql: "PRAGMA user_version;") ?? 0
        guard currentVersion < 2 else { return }

        guard execute("BEGIN IMMEDIATE;", in: database) else { return }
        let columns = [
            ("vision_pending_jobs", "idempotency_key", "TEXT"),
            ("vision_pending_jobs", "server_request_id", "TEXT"),
            ("vision_pending_jobs", "location", "TEXT"),
            ("vision_pending_jobs", "retry_after", "INTEGER")
        ]
        for (table, column, definition) in columns {
            ensureColumn(column, definition: definition, in: table, database: database)
        }

        let statements = [
            "UPDATE vision_pending_jobs SET idempotency_key = request_id WHERE idempotency_key IS NULL;",
            "CREATE UNIQUE INDEX IF NOT EXISTS idx_vision_pending_idempotency ON vision_pending_jobs(account_id, capability, idempotency_key) WHERE idempotency_key IS NOT NULL;",
            "PRAGMA user_version = 2;"
        ]
        guard statements.allSatisfy({ execute($0, in: database) }) else {
            _ = execute("ROLLBACK;", in: database)
            return
        }
        _ = execute("COMMIT;", in: database)
    }

    /// v1.2 统一视觉任务只持久化恢复 Job 所需字段，同时移除旧 demo 结果缓存表。
    private func applyUnifiedVisionJobMigration(database: OpaquePointer) {
        let currentVersion = scalarInt(database, sql: "PRAGMA user_version;") ?? 0
        guard currentVersion < 3 else { return }
        let statements = [
            "BEGIN IMMEDIATE;",
            """
            CREATE TABLE vision_pending_jobs_v3 (
                account_id TEXT NOT NULL,
                capability TEXT NOT NULL,
                request_id TEXT NOT NULL,
                idempotency_key TEXT,
                job_id TEXT,
                status TEXT NOT NULL,
                server_request_id TEXT,
                location TEXT,
                retry_after INTEGER,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                PRIMARY KEY(account_id, capability)
            );
            """,
            """
            INSERT INTO vision_pending_jobs_v3 (
                account_id, capability, request_id, idempotency_key, job_id, status,
                server_request_id, location, retry_after, created_at, updated_at
            ) SELECT account_id, capability, request_id, idempotency_key, job_id, status,
                     server_request_id, location, retry_after, created_at, updated_at
              FROM vision_pending_jobs;
            """,
            "DROP TABLE vision_pending_jobs;",
            "ALTER TABLE vision_pending_jobs_v3 RENAME TO vision_pending_jobs;",
            "CREATE UNIQUE INDEX idx_vision_pending_idempotency ON vision_pending_jobs(account_id, capability, idempotency_key) WHERE idempotency_key IS NOT NULL;",
            "DROP TABLE IF EXISTS demo_recognition_attempts;",
            "DROP TABLE IF EXISTS demo_results;",
            "DROP TABLE IF EXISTS demo_assets;",
            "PRAGMA user_version = 3;",
            "COMMIT;"
        ]
        for statement in statements {
            guard execute(statement, in: database) else {
                _ = execute("ROLLBACK;", in: database)
                return
            }
        }
    }

    /// Hermes 文本对话按登录账号分区缓存；移除不符合正式契约的旧演示聊天记录和字段。
    private func applyChatHermesMigration(database: OpaquePointer) {
        let currentVersion = scalarInt(database, sql: "PRAGMA user_version;") ?? 0
        guard currentVersion < 4 else { return }

        guard execute("BEGIN IMMEDIATE;", in: database) else { return }
        let statements = [
            "CREATE TABLE IF NOT EXISTS chat_conversations (user_id TEXT PRIMARY KEY, conversation_id TEXT NOT NULL UNIQUE, created_at REAL NOT NULL, updated_at REAL NOT NULL, FOREIGN KEY(user_id) REFERENCES users(user_id));",
            "DROP TABLE IF EXISTS chat_messages_v4;",
            "CREATE TABLE chat_messages_v4 (id TEXT PRIMARY KEY, user_id TEXT NOT NULL, conversation_id TEXT, sender TEXT NOT NULL, text TEXT NOT NULL, ai_avatar_name TEXT, client_request_id TEXT, server_message_id TEXT, server_request_id TEXT, delivery_status TEXT NOT NULL DEFAULT 'completed', error_code TEXT, error_detail TEXT, http_status INTEGER, created_at REAL NOT NULL, updated_at REAL NOT NULL DEFAULT 0, FOREIGN KEY(user_id) REFERENCES users(user_id));",
            "DROP TABLE chat_messages;",
            "ALTER TABLE chat_messages_v4 RENAME TO chat_messages;",
            "CREATE INDEX idx_chat_user_conversation_time ON chat_messages(user_id, conversation_id, created_at);",
            "CREATE UNIQUE INDEX idx_chat_request_sender ON chat_messages(user_id, conversation_id, client_request_id, sender) WHERE client_request_id IS NOT NULL;",
            "PRAGMA user_version = 4;",
            "COMMIT;"
        ]
        for statement in statements {
            guard execute(statement, in: database) else {
                _ = execute("ROLLBACK;", in: database)
                return
            }
        }
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

    @discardableResult
    private func execute(_ sql: String, in database: OpaquePointer) -> Bool {
        var error: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(database, sql, nil, nil, &error)
        if let error { sqlite3_free(error) }
        return result == SQLITE_OK
    }

    private func seedIfNeeded() {
        guard let db else { return }
        let count = scalarInt(db, sql: "SELECT COUNT(*) FROM users;") ?? 0
        guard count == 0 else { return }

        DatabaseSeeder.seed(into: db)
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
