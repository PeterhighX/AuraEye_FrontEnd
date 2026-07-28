import Foundation
import SQLite3

/// 眼型库 — 对应 `后端数据库.md` eye_styles / YouCam
final class EyeStyleRepository {
    private let db: DatabaseManager

    init(db: DatabaseManager = .shared) {
        self.db = db
    }

    func fetchAll() throws -> [EyeStyle] {
        try db.perform { db in
            let sql = "SELECT * FROM eye_styles ORDER BY eye_style_name ASC;"
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }

            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed
            }

            var results: [EyeStyle] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                results.append(map(statement))
            }
            return results
        }
    }

    func fetch(scene: String) throws -> EyeStyle? {
        try db.perform { db in
            let sql = "SELECT * FROM eye_styles WHERE scene = ? LIMIT 1;"
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }

            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
            sqlite3_bind_text(statement, 1, scene, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
            return map(statement)
        }
    }

    private func map(_ statement: OpaquePointer?) -> EyeStyle {
        EyeStyle(
            eyeStyleName: columnText(statement, 0) ?? "",
            eyeSVG: columnText(statement, 1),
            eyelinerName: columnText(statement, 2),
            eyelinerSVG: columnText(statement, 3),
            eyeColorMain: columnText(statement, 4),
            eyeColorSub: columnText(statement, 5),
            scene: columnText(statement, 6)
        )
    }

    private func columnText(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        guard let cString = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: cString)
    }
}
