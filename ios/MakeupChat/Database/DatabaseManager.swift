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

    func perform<T>(_ work: (OpaquePointer) throws -> T) rethrows -> T {
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
