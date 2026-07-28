import Foundation
import SQLite3

final class ChatRepository {
    private let db: DatabaseManager

    init(db: DatabaseManager = .shared) {
        self.db = db
    }

    func fetchMessages(userId: String) throws -> [ChatMessage] {
        try db.perform { db in
            let sql = """
            SELECT id, sender, text, image_asset_name, image_path,
                   ai_avatar_name, message_kind, created_at
            FROM chat_messages
            WHERE user_id = ?
            ORDER BY created_at ASC;
            """
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }

            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed
            }
            sqlite3_bind_text(statement, 1, userId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

            var messages: [ChatMessage] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                messages.append(mapMessage(statement))
            }
            return messages
        }
    }

    func insert(_ message: ChatMessage, userId: String) throws {
        try db.perform { db in
            let sql = """
            INSERT INTO chat_messages (
                id, user_id, sender, text, image_asset_name, image_path,
                ai_avatar_name, message_kind, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }

            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed
            }

            sqlite3_bind_text(statement, 1, message.id, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(statement, 2, userId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(statement, 3, message.sender.rawValue, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(statement, 4, message.text, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

            if let imageName = message.imageName {
                sqlite3_bind_text(statement, 5, imageName, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            } else {
                sqlite3_bind_null(statement, 5)
            }

            if let imagePath = message.imagePath {
                sqlite3_bind_text(statement, 6, imagePath, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            } else {
                sqlite3_bind_null(statement, 6)
            }

            sqlite3_bind_text(statement, 7, message.aiAvatarName, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(statement, 8, message.kind.rawValue, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_double(statement, 9, message.createdAt.timeIntervalSince1970)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw DatabaseError.executionFailed
            }
        }
    }

    private func mapMessage(_ statement: OpaquePointer?) -> ChatMessage {
        ChatMessage(
            id: columnText(statement, 0) ?? UUID().uuidString,
            sender: ChatSender(rawValue: columnText(statement, 1) ?? "ai") ?? .ai,
            text: columnText(statement, 2) ?? "",
            imageName: columnText(statement, 3),
            imagePath: columnText(statement, 4),
            aiAvatarName: columnText(statement, 5) ?? "AvatarAI",
            kind: ChatMessageKind(rawValue: columnText(statement, 6) ?? "text") ?? .text,
            createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 7))
        )
    }

    private func columnText(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        guard let cString = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: cString)
    }
}
