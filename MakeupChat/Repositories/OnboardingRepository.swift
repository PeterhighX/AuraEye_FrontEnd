import Foundation
import SQLite3

final class OnboardingRepository {
    private let db: DatabaseManager

    init(db: DatabaseManager = .shared) {
        self.db = db
    }

    func ensureDefaultSteps(userId: String) throws {
        let count = try stepCount(userId: userId)
        guard count == 0 else { return }

        let now = Date().timeIntervalSince1970
        for key in OnboardingStepKey.allCases {
            let status: OnboardingStepStatus = key == .userProfile ? .inProgress : .pending
            try insert(
                OnboardingStep(
                    id: "\(userId)_\(key.rawValue)",
                    userId: userId,
                    stepKey: key,
                    status: status,
                    subtitle: key.defaultSubtitle,
                    previewAsset: key.defaultPreviewAsset,
                    previewPath: nil,
                    updatedAt: Date(timeIntervalSince1970: now)
                )
            )
        }
    }

    func resetForNewLaunch(userId: String) throws {
        try db.perform { db in
            let sql = """
            UPDATE onboarding_steps
            SET status = CASE WHEN step_key = 'user_profile' THEN 'in_progress' ELSE 'pending' END,
                subtitle = CASE step_key
                    WHEN 'user_profile' THEN '✨ 闪闪正在用火眼金睛分析你的面部特征哦'
                    WHEN 'cosmetics' THEN '✨ 闪闪正在认真翻看宝子自己有哪些化妆品……'
                    ELSE '✨ 正在为你规划最不容易手残的保姆级步骤……'
                END,
                preview_asset = CASE step_key
                    WHEN 'user_profile' THEN 'OnboardingUserProfileProvided'
                    WHEN 'cosmetics' THEN 'OnboardingCosmeticsProvided'
                    ELSE 'OnboardingChooseLookProvided'
                END,
                preview_path = NULL,
                updated_at = ?
            WHERE user_id = ?;
            """
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed
            }
            sqlite3_bind_double(statement, 1, Date().timeIntervalSince1970)
            sqlite3_bind_text(statement, 2, userId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw DatabaseError.executionFailed
            }
        }
    }

    func fetchSteps(userId: String) throws -> [OnboardingStep] {
        try db.perform { db in
            let sql = """
            SELECT id, user_id, step_key, status, subtitle, preview_asset, preview_path, updated_at
            FROM onboarding_steps
            WHERE user_id = ?
            ORDER BY step_index ASC;
            """
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }

            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed
            }
            sqlite3_bind_text(statement, 1, userId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

            var results: [OnboardingStep] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                if let step = mapStep(statement) {
                    results.append(step)
                }
            }
            return results
        }
    }

    func updateStep(
        userId: String,
        key: OnboardingStepKey,
        status: OnboardingStepStatus,
        subtitle: String? = nil,
        previewPath: String? = nil
    ) throws {
        let stored = previewPath.map { LocalMediaStore.normalizeForStorage($0) ?? $0 }
        try db.perform { db in
            let sql = """
            UPDATE onboarding_steps
            SET status = ?, subtitle = COALESCE(?, subtitle),
                preview_path = COALESCE(?, preview_path), updated_at = ?
            WHERE user_id = ? AND step_key = ?;
            """
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }

            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed
            }

            let now = Date().timeIntervalSince1970
            sqlite3_bind_text(statement, 1, status.rawValue, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            bindOptionalText(statement, 2, subtitle)
            bindOptionalText(statement, 3, stored)
            sqlite3_bind_double(statement, 4, now)
            sqlite3_bind_text(statement, 5, userId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(statement, 6, key.rawValue, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw DatabaseError.executionFailed
            }
        }
    }

    func activateNextStep(after key: OnboardingStepKey, userId: String) throws {
        let nextKey: OnboardingStepKey?
        switch key {
        case .userProfile: nextKey = .cosmetics
        case .cosmetics: nextKey = .makeupGenerate
        case .makeupGenerate: nextKey = nil
        }
        guard let nextKey else { return }
        if let next = try fetchSteps(userId: userId).first(where: { $0.stepKey == nextKey }),
           next.isCompleted {
            // 支持用户先从首页/陈列柜完成 Step 2：
            // Step 1 完成后跳过已完成项，直接激活 Step 3。
            try activateNextStep(after: nextKey, userId: userId)
            return
        }
        try updateStep(userId: userId, key: nextKey, status: .inProgress)
    }

    private func stepCount(userId: String) throws -> Int {
        try db.perform { db in
            let sql = "SELECT COUNT(*) FROM onboarding_steps WHERE user_id = ?;"
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return 0 }
            sqlite3_bind_text(statement, 1, userId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
            return Int(sqlite3_column_int(statement, 0))
        }
    }

    private func insert(_ step: OnboardingStep) throws {
        try db.perform { db in
            let sql = """
            INSERT INTO onboarding_steps (
                id, user_id, step_key, step_index, status, subtitle,
                preview_asset, preview_path, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }

            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed
            }

            sqlite3_bind_text(statement, 1, step.id, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(statement, 2, step.userId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(statement, 3, step.stepKey.rawValue, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_int(statement, 4, Int32(step.stepNumber))
            sqlite3_bind_text(statement, 5, step.status.rawValue, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(statement, 6, step.subtitle, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            bindOptionalText(statement, 7, step.previewAsset)
            bindOptionalText(statement, 8, step.previewPath)
            sqlite3_bind_double(statement, 9, step.updatedAt.timeIntervalSince1970)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw DatabaseError.executionFailed
            }
        }
    }

    private func mapStep(_ statement: OpaquePointer?) -> OnboardingStep? {
        guard
            let id = columnText(statement, 0),
            let userId = columnText(statement, 1),
            let keyRaw = columnText(statement, 2),
            let key = OnboardingStepKey(rawValue: keyRaw),
            let statusRaw = columnText(statement, 3),
            let status = OnboardingStepStatus(rawValue: statusRaw),
            let subtitle = columnText(statement, 5)
        else { return nil }

        return OnboardingStep(
            id: id,
            userId: userId,
            stepKey: key,
            status: status,
            subtitle: subtitle,
            previewAsset: columnText(statement, 6),
            previewPath: columnText(statement, 7),
            updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 8))
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
