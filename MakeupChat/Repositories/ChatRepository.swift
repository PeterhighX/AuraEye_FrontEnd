import Foundation
import SQLite3

/// 远端聊天的本地缓存。所有查询都必须限定登录用户和 conversation。
final class ChatRepository {
    private let db: DatabaseManager

    init(db: DatabaseManager = .shared) {
        self.db = db
    }

    func conversationID(for userId: String) throws -> String {
        try db.perform { db in
            if let existing = scalarText(db, sql: "SELECT conversation_id FROM chat_conversations WHERE user_id = ? LIMIT 1;", bindings: [userId]), !existing.isEmpty {
                return existing
            }
            let now = Date().timeIntervalSince1970
            let conversationID = "conversation_\(UUID().uuidString.lowercased())"
            try execute(db, sql: "INSERT INTO chat_conversations (user_id, conversation_id, created_at, updated_at) VALUES (?, ?, ?, ?);", bindings: [userId, conversationID, now, now])
            return conversationID
        }
    }

    func fetchMessages(userId: String, conversationId: String) throws -> [ChatMessage] {
        try db.perform { db in
            let sql = """
            SELECT id, user_id, conversation_id, sender, text, ai_avatar_name,
                   client_request_id, server_message_id, server_request_id,
                   delivery_status, error_code, error_detail, http_status,
                   created_at, updated_at
            FROM chat_messages
            WHERE user_id = ? AND conversation_id = ?
            ORDER BY created_at ASC, id ASC;
            """
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { throw DatabaseError.prepareFailed }
            bind(userId, to: statement, at: 1)
            bind(conversationId, to: statement, at: 2)
            var messages: [ChatMessage] = []
            while sqlite3_step(statement) == SQLITE_ROW { messages.append(mapMessage(statement)) }
            return messages
        }
    }

    func insertSendingExchange(userId: String, conversationId: String, requestId: String, text: String) throws {
        try db.perform { db in
            guard executeRaw("BEGIN IMMEDIATE;", in: db) else { throw DatabaseError.executionFailed }
            do {
                let now = Date().timeIntervalSince1970
                try execute(db, sql: """
                INSERT INTO chat_messages (
                    id, user_id, conversation_id, sender, text, ai_avatar_name,
                    client_request_id, delivery_status, created_at, updated_at
                ) VALUES (?, ?, ?, 'user', ?, 'AvatarUser', ?, 'sending', ?, ?);
                """, bindings: [UUID().uuidString, userId, conversationId, text, requestId, now, now])
                try execute(db, sql: """
                INSERT INTO chat_messages (
                    id, user_id, conversation_id, sender, text, ai_avatar_name,
                    client_request_id, delivery_status, created_at, updated_at
                ) VALUES (?, ?, ?, 'ai', '', 'AvatarAI2', ?, 'streaming', ?, ?);
                """, bindings: ["assistant_\(UUID().uuidString)", userId, conversationId, requestId, now + 0.000_001, now])
                try touchConversation(db, userId: userId, at: now)
                guard executeRaw("COMMIT;", in: db) else { throw DatabaseError.executionFailed }
            } catch {
                _ = executeRaw("ROLLBACK;", in: db)
                throw error
            }
        }
    }

    func bindAssistantMessageID(userId: String, conversationId: String, requestId: String, messageId: String) throws {
        try db.perform { db in
            try execute(db, sql: """
            UPDATE chat_messages SET server_message_id = ?, updated_at = ?
            WHERE user_id = ? AND conversation_id = ? AND sender = 'ai' AND client_request_id = ?;
            """, bindings: [messageId, Date().timeIntervalSince1970, userId, conversationId, requestId])
            guard sqlite3_changes(db) == 1 else { throw ChatStorageError.messageNotFound }
        }
    }

    func replaceStreamingAssistantText(userId: String, conversationId: String, requestId: String, text: String) throws {
        try db.perform { db in
            try execute(db, sql: """
            UPDATE chat_messages SET text = ?, delivery_status = 'streaming', updated_at = ?
            WHERE user_id = ? AND conversation_id = ? AND sender = 'ai' AND client_request_id = ?;
            """, bindings: [text, Date().timeIntervalSince1970, userId, conversationId, requestId])
            guard sqlite3_changes(db) == 1 else { throw ChatStorageError.messageNotFound }
        }
    }

    func completeStreaming(userId: String, conversationId: String, reply: ChatReply) throws {
        try db.perform { db in
            guard executeRaw("BEGIN IMMEDIATE;", in: db) else { throw DatabaseError.executionFailed }
            do {
                let now = Date().timeIntervalSince1970
                try execute(db, sql: """
                UPDATE chat_messages
                SET delivery_status = 'completed', server_request_id = ?, error_code = NULL,
                    error_detail = NULL, http_status = NULL, updated_at = ?
                WHERE user_id = ? AND conversation_id = ? AND sender = 'user' AND client_request_id = ?;
                """, bindings: [reply.serverRequestId, now, userId, conversationId, reply.clientRequestId])
                guard sqlite3_changes(db) == 1 else { throw ChatStorageError.messageNotFound }
                try execute(db, sql: """
                UPDATE chat_messages
                SET text = ?, ai_avatar_name = ?, server_message_id = ?, server_request_id = ?,
                    delivery_status = 'completed', error_code = NULL, error_detail = NULL,
                    http_status = NULL, updated_at = ?
                WHERE user_id = ? AND conversation_id = ? AND sender = 'ai' AND client_request_id = ?;
                """, bindings: [reply.message, reply.avatarAsset, reply.messageId, reply.serverRequestId, now, userId, conversationId, reply.clientRequestId])
                guard sqlite3_changes(db) == 1 else { throw ChatStorageError.messageNotFound }
                try touchConversation(db, userId: userId, at: now)
                guard executeRaw("COMMIT;", in: db) else { throw DatabaseError.executionFailed }
            } catch {
                _ = executeRaw("ROLLBACK;", in: db)
                throw error
            }
        }
    }

    func discardStreamingAssistant(userId: String, conversationId: String, requestId: String) throws {
        try db.perform { db in
            try execute(db, sql: """
            DELETE FROM chat_messages
            WHERE user_id = ? AND conversation_id = ? AND sender = 'ai'
              AND client_request_id = ? AND delivery_status = 'streaming';
            """, bindings: [userId, conversationId, requestId])
        }
    }

    func markFailed(userId: String, conversationId: String, requestId: String, failure: ChatRequestFailure) throws {
        try db.perform { db in
            try execute(db, sql: """
            UPDATE chat_messages
            SET delivery_status = ?, server_request_id = ?, error_code = ?, error_detail = ?, http_status = ?, updated_at = ?
            WHERE user_id = ? AND conversation_id = ? AND sender = 'user' AND client_request_id = ?;
            """, bindings: [failure.retryable ? ChatDeliveryStatus.failedRetryable.rawValue : ChatDeliveryStatus.failedPermanent.rawValue, failure.serverRequestId, failure.code, failure.detail, failure.httpStatus, Date().timeIntervalSince1970, userId, conversationId, requestId])
            guard sqlite3_changes(db) == 1 else { throw ChatStorageError.messageNotFound }
        }
    }

    func retryPayload(userId: String, conversationId: String, localMessageId: String) throws -> ChatSendRequest? {
        try db.perform { db in
            let sql = """
            SELECT client_request_id, text, delivery_status
            FROM chat_messages
            WHERE id = ? AND user_id = ? AND conversation_id = ? AND sender = 'user'
            LIMIT 1;
            """
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { throw DatabaseError.prepareFailed }
            bind(localMessageId, to: statement, at: 1)
            bind(userId, to: statement, at: 2)
            bind(conversationId, to: statement, at: 3)
            guard sqlite3_step(statement) == SQLITE_ROW,
                  let requestId = text(statement, 0), let message = text(statement, 1),
                  ChatDeliveryStatus(rawValue: text(statement, 2) ?? "")?.isRetryable == true else { return nil }
            return ChatSendRequest(requestId: requestId, conversationId: conversationId, message: message)
        }
    }

    func markRetrying(userId: String, conversationId: String, requestId: String) throws {
        try db.perform { db in
            guard executeRaw("BEGIN IMMEDIATE;", in: db) else { throw DatabaseError.executionFailed }
            do {
                let now = Date().timeIntervalSince1970
                try execute(db, sql: """
                UPDATE chat_messages
                SET delivery_status = 'sending', error_code = NULL, error_detail = NULL, http_status = NULL, updated_at = ?
                WHERE user_id = ? AND conversation_id = ? AND sender = 'user' AND client_request_id = ?;
                """, bindings: [now, userId, conversationId, requestId])
                guard sqlite3_changes(db) == 1 else { throw ChatStorageError.messageNotFound }
                try execute(db, sql: """
                INSERT OR IGNORE INTO chat_messages (
                    id, user_id, conversation_id, sender, text, ai_avatar_name,
                    client_request_id, delivery_status, created_at, updated_at
                ) VALUES (?, ?, ?, 'ai', '', 'AvatarAI2', ?, 'streaming', ?, ?);
                """, bindings: ["assistant_\(UUID().uuidString)", userId, conversationId, requestId, now + 0.000_001, now])
                guard executeRaw("COMMIT;", in: db) else { throw DatabaseError.executionFailed }
            } catch {
                _ = executeRaw("ROLLBACK;", in: db)
                throw error
            }
        }
    }

    private func touchConversation(_ db: OpaquePointer, userId: String, at timestamp: TimeInterval) throws {
        try execute(db, sql: "UPDATE chat_conversations SET updated_at = ? WHERE user_id = ?;", bindings: [timestamp, userId])
    }

    private func execute(_ db: OpaquePointer, sql: String, bindings: [Any?]) throws {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { throw DatabaseError.prepareFailed }
        for (index, value) in bindings.enumerated() { bind(value, to: statement, at: Int32(index + 1)) }
        guard sqlite3_step(statement) == SQLITE_DONE else { throw DatabaseError.executionFailed }
    }

    private func executeRaw(_ sql: String, in db: OpaquePointer) -> Bool { sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK }

    private func scalarText(_ db: OpaquePointer, sql: String, bindings: [Any?]) -> String? {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
        for (index, value) in bindings.enumerated() { bind(value, to: statement, at: Int32(index + 1)) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return text(statement, 0)
    }

    private func mapMessage(_ statement: OpaquePointer?) -> ChatMessage {
        ChatMessage(id: text(statement, 0) ?? UUID().uuidString, userId: text(statement, 1) ?? "", conversationId: text(statement, 2) ?? "", sender: ChatSender(rawValue: text(statement, 3) ?? "ai") ?? .ai, text: text(statement, 4) ?? "", aiAvatarName: text(statement, 5) ?? "AvatarAI2", clientRequestId: text(statement, 6), serverMessageId: text(statement, 7), serverRequestId: text(statement, 8), deliveryStatus: ChatDeliveryStatus(rawValue: text(statement, 9) ?? "completed") ?? .completed, errorCode: text(statement, 10), errorDetail: text(statement, 11), httpStatus: sqlite3_column_type(statement, 12) == SQLITE_NULL ? nil : Int(sqlite3_column_int(statement, 12)), createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 13)), updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 14)))
    }

    private func bind(_ value: Any?, to statement: OpaquePointer?, at index: Int32) {
        switch value {
        case let value as String: sqlite3_bind_text(statement, index, value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        case let value as Double: sqlite3_bind_double(statement, index, value)
        case let value as Int: sqlite3_bind_int64(statement, index, sqlite3_int64(value))
        case nil: sqlite3_bind_null(statement, index)
        default: sqlite3_bind_null(statement, index)
        }
    }

    private func text(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        guard let value = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: value)
    }
}

enum ChatStorageError: LocalizedError {
    case messageNotFound
    var errorDescription: String? { "本地对话记录不存在或已过期。" }
}
