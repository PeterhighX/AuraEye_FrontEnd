import Foundation
import SQLite3

final class MakeupCatalogRepository {
    private let db: DatabaseManager

    init(db: DatabaseManager = .shared) {
        self.db = db
    }

    func eyeStyle(for scene: String) throws -> EyeStyle? {
        try db.perform { db in
            let sql = "SELECT * FROM eye_styles WHERE scene = ? LIMIT 1;"
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }

            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
            sqlite3_bind_text(statement, 1, scene, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            guard sqlite3_step(statement) == SQLITE_ROW else { return nil }

            return EyeStyle(
                eyeStyleName: columnText(statement, 0) ?? "",
                eyeSVG: columnText(statement, 1),
                eyelinerName: columnText(statement, 2),
                eyelinerSVG: columnText(statement, 3),
                eyeColorMain: columnText(statement, 4),
                eyeColorSub: columnText(statement, 5),
                scene: columnText(statement, 6)
            )
        }
    }

    func cosmeticTip() throws -> String? {
        try db.perform { db in
            let sql = "SELECT brush_json FROM cosmetics LIMIT 1;"
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }

            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
            guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
            guard
                let json = columnText(statement, 0),
                let data = json.data(using: .utf8),
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let tip = object["tip"] as? String
            else { return nil }

            return tip
        }
    }

    private func columnText(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        guard let cString = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: cString)
    }
}
