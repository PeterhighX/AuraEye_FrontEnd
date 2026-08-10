import Foundation
import SQLite3

struct VisionPendingJob: Sendable {
    let accountID: String
    let capability: VisionCapability
    let requestID: String
    let idempotencyKey: String
    let jobID: String?
    let status: String
    let serverRequestID: String?
    let location: String?
    let retryAfterSeconds: Int?
}

final class VisionJobPersistence {
    private let db: DatabaseManager

    init(db: DatabaseManager = .shared) {
        self.db = db
    }

    func pendingJob(accountID: String, capability: VisionCapability) throws -> VisionPendingJob? {
        try db.perform { database in
            let sql = """
            SELECT account_id, capability, request_id, idempotency_key, job_id, status,
                   server_request_id, location, retry_after
            FROM vision_pending_jobs WHERE account_id = ? AND capability = ? LIMIT 1;
            """
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed
            }
            bind(accountID, to: statement, at: 1)
            bind(capability.rawValue, to: statement, at: 2)
            guard sqlite3_step(statement) == SQLITE_ROW,
                  let decodedCapability = text(statement, 1).flatMap(VisionCapability.init(rawValue:)) else {
                return nil
            }
            return VisionPendingJob(
                accountID: text(statement, 0) ?? "",
                capability: decodedCapability,
                requestID: text(statement, 2) ?? "",
                idempotencyKey: text(statement, 3) ?? text(statement, 2) ?? "",
                jobID: text(statement, 4),
                status: text(statement, 5) ?? "",
                serverRequestID: text(statement, 6),
                location: text(statement, 7),
                retryAfterSeconds: optionalInt(statement, 8)
            )
        }
    }

    func savePendingJob(_ job: VisionPendingJob) throws {
        try db.perform { database in
            let sql = """
            INSERT INTO vision_pending_jobs (
                account_id, capability, request_id, idempotency_key, job_id, status,
                server_request_id, location, retry_after, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(account_id, capability) DO UPDATE SET
                request_id = excluded.request_id,
                idempotency_key = excluded.idempotency_key,
                job_id = COALESCE(excluded.job_id, job_id),
                status = excluded.status,
                server_request_id = COALESCE(excluded.server_request_id, server_request_id),
                location = COALESCE(excluded.location, location),
                retry_after = COALESCE(excluded.retry_after, retry_after),
                updated_at = excluded.updated_at;
            """
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed
            }
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let values: [String?] = [
                job.accountID,
                job.capability.rawValue,
                job.requestID,
                job.idempotencyKey,
                job.jobID,
                job.status,
                job.serverRequestID,
                job.location
            ]
            values.enumerated().forEach {
                bindOptional($0.element, to: statement, at: Int32($0.offset + 1))
            }
            bindOptionalInt(job.retryAfterSeconds, to: statement, at: 9)
            bind(timestamp, to: statement, at: 10)
            bind(timestamp, to: statement, at: 11)
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw DatabaseError.executionFailed
            }
        }
    }

    func removePendingJob(accountID: String, capability: VisionCapability) throws {
        try db.perform { database in
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            guard sqlite3_prepare_v2(
                database,
                "DELETE FROM vision_pending_jobs WHERE account_id = ? AND capability = ?;",
                -1,
                &statement,
                nil
            ) == SQLITE_OK else {
                throw DatabaseError.prepareFailed
            }
            bind(accountID, to: statement, at: 1)
            bind(capability.rawValue, to: statement, at: 2)
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw DatabaseError.executionFailed
            }
        }
    }
}

private func bind(_ value: String, to statement: OpaquePointer?, at index: Int32) {
    sqlite3_bind_text(statement, index, value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
}

private func bindOptional(_ value: String?, to statement: OpaquePointer?, at index: Int32) {
    if let value { bind(value, to: statement, at: index) }
    else { sqlite3_bind_null(statement, index) }
}

private func bindOptionalInt(_ value: Int?, to statement: OpaquePointer?, at index: Int32) {
    if let value { sqlite3_bind_int64(statement, index, sqlite3_int64(value)) }
    else { sqlite3_bind_null(statement, index) }
}

private func text(_ statement: OpaquePointer?, _ index: Int32) -> String? {
    guard let value = sqlite3_column_text(statement, index) else { return nil }
    return String(cString: value)
}

private func optionalInt(_ statement: OpaquePointer?, _ index: Int32) -> Int? {
    guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
    return Int(sqlite3_column_int64(statement, index))
}
