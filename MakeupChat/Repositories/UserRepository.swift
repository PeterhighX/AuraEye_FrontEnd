import Foundation
import SQLite3

final class UserRepository {
    private let db: DatabaseManager

    init(db: DatabaseManager = .shared) {
        self.db = db
    }

    func currentUser() throws -> UserProfile {
        try db.perform { db in
            let sql = "SELECT * FROM users ORDER BY updated_at DESC LIMIT 1;"
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }

            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed
            }
            guard sqlite3_step(statement) == SQLITE_ROW else {
                throw DatabaseError.executionFailed
            }
            return mapUser(statement)
        }
    }

    func fetch(userId: String) throws -> UserProfile? {
        try db.perform { db in
            let sql = "SELECT * FROM users WHERE user_id = ? LIMIT 1;"
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed
            }
            sqlite3_bind_text(statement, 1, userId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
            return mapUser(statement)
        }
    }

    func upsertChatUser(userId: String, displayName: String) throws -> UserProfile {
        let normalizedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let now = Date().timeIntervalSince1970
        try db.perform { db in
            let sql = """
            INSERT INTO users (user_id, display_name, status, credits, updated_at)
            VALUES (?, ?, '开心', 0, ?)
            ON CONFLICT(user_id) DO UPDATE SET
                display_name = excluded.display_name,
                updated_at = excluded.updated_at;
            """
            try exec(db, sql: sql, bindings: [userId, normalizedName.isEmpty ? userId : normalizedName, now])
        }
        guard let user = try fetch(userId: userId) else { throw DatabaseError.executionFailed }
        return user
    }

    func update(_ user: UserProfile) throws {
        try db.perform { db in
            let sql = """
            UPDATE users SET
                display_name = ?, status = ?, credits = ?, user_file = ?,
                user_portrait = ?, user_update_photo = ?, eye_preview = ?,
                eye_steps = ?, updated_at = ?
            WHERE user_id = ?;
            """
            try exec(db, sql: sql, bindings: [
                user.displayName, user.status, user.credits, user.userFileJSON,
                LocalMediaStore.normalizeForStorage(user.userPortraitPath),
                LocalMediaStore.normalizeForStorage(user.uploadedPhotoPath),
                LocalMediaStore.normalizeForStorage(user.eyePreviewPath),
                user.eyeStepsJSON, Date().timeIntervalSince1970, user.userId
            ])
        }
    }

    func updateUploadedPhoto(userId: String, path: String) throws {
        let stored = LocalMediaStore.normalizeForStorage(path) ?? path
        try db.perform { db in
            let sql = "UPDATE users SET user_update_photo = ?, updated_at = ? WHERE user_id = ?;"
            try exec(db, sql: sql, bindings: [stored, Date().timeIntervalSince1970, userId])
        }
    }

    func updateEyePreview(userId: String, previewPath: String, stepsJSON: String?) throws {
        let stored = LocalMediaStore.normalizeForStorage(previewPath) ?? previewPath
        try db.perform { db in
            let sql = "UPDATE users SET eye_preview = ?, eye_steps = ?, updated_at = ? WHERE user_id = ?;"
            try exec(db, sql: sql, bindings: [stored, stepsJSON, Date().timeIntervalSince1970, userId])
        }
    }

    private func mapUser(_ statement: OpaquePointer?) -> UserProfile {
        UserProfile(
            userId: columnText(statement, 0) ?? "",
            displayName: columnText(statement, 1) ?? "User",
            status: columnText(statement, 2) ?? "开心",
            credits: Int(sqlite3_column_int(statement, 3)),
            userFileJSON: columnText(statement, 4),
            userPortraitPath: columnText(statement, 5),
            uploadedPhotoPath: columnText(statement, 6),
            eyePreviewPath: columnText(statement, 7),
            eyeStepsJSON: columnText(statement, 8)
        )
    }

    private func exec(_ db: OpaquePointer, sql: String, bindings: [Any?]) throws {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed
        }

        for (index, value) in bindings.enumerated() {
            let position = Int32(index + 1)
            if let text = value as? String {
                sqlite3_bind_text(statement, position, text, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            } else if let number = value as? Int {
                sqlite3_bind_int64(statement, position, sqlite3_int64(number))
            } else if let number = value as? Double {
                sqlite3_bind_double(statement, position, number)
            } else if value == nil {
                sqlite3_bind_null(statement, position)
            }
        }

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.executionFailed
        }
    }

    private func columnText(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        guard let cString = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: cString)
    }
}
