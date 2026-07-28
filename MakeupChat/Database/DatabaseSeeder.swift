import Foundation
import SQLite3

enum DatabaseSeeder {
    static func seed(into db: OpaquePointer) {
        let now = Date().timeIntervalSince1970
        let userFile = """
        {"nickname":"Mrs.Zhang","mood":"开心","skinTone":"自然","preference":"清新"}
        """

        exec(db, sql: """
        INSERT INTO users (
            user_id, display_name, status, credits, user_file,
            user_portrait, user_update_photo, eye_preview, eye_steps, updated_at
        ) VALUES (?, ?, ?, ?, ?, NULL, NULL, NULL, NULL, ?);
        """, bindings: [
            .text("mrs_zhang"),
            .text("Mrs.Zhang"),
            .text("开心"),
            .int(50),
            .text(userFile),
            .double(now)
        ])

        exec(db, sql: """
        INSERT INTO eye_styles (
            eye_style_name, eye_svg, eyeliner_name, eyeliner_svg,
            eye_color_main, eye_color_sub, scene
        ) VALUES (?, ?, ?, ?, ?, ?, ?);
        """, bindings: [
            .text("1color42"),
            .text("eye_1color42.svg"),
            .text("Arabic3"),
            .text("eyeliner_arabic3.svg"),
            .text("#C4A484"),
            .text("#8B7355"),
            .text("日常")
        ])

        exec(db, sql: """
        INSERT INTO cosmetics (sku, user_id, makeup_cat, makeup_tab, makeup_colors, brush_json, preview_path, scanned_at)
        VALUES (?, ?, ?, ?, ?, ?, NULL, ?);
        """, bindings: [
            .text("eyeshadow_palette_01"),
            .text("mrs_zhang"),
            .text("眼影"),
            .text("大地色系"),
            .text("[\"#D4B896\",\"#C4A484\",\"#E8C4B8\"]"),
            .text("{\"name\":\"眼影盘01\"}"),
            .double(now)
        ])

        exec(db, sql: """
        INSERT INTO cosmetics (sku, user_id, makeup_cat, makeup_tab, makeup_colors, brush_json, preview_path, scanned_at)
        VALUES (?, ?, ?, ?, ?, ?, NULL, ?);
        """, bindings: [
            .text("eyeliner_pen_01"),
            .text("mrs_zhang"),
            .text("眼线"),
            .text("[\"钢制刷头\",\"欧式大刷\"]"),
            .null,
            .text("{\"name\":\"眼线笔 01\"}"),
            .double(now)
        ])

        exec(db, sql: """
        INSERT INTO cosmetics (sku, user_id, makeup_cat, makeup_tab, makeup_colors, brush_json, preview_path, scanned_at)
        VALUES (?, ?, ?, ?, ?, ?, NULL, ?);
        """, bindings: [
            .text("brush_soft_01"),
            .text("mrs_zhang"),
            .text("毛刷"),
            .text("羊毛刷头"),
            .null,
            .text("{\"name\":\"毛刷 01\",\"tip\":\"毛刷的作用可以柔化边缘，但是要定时清理哦！\"}"),
            .double(now)
        ])

        let demoMessages: [(String, String, String, String?, String?, String)] = [
            ("ai", "Mrs Zhang，请给我一张图片帮你生成今日的妆容", "AvatarAI", nil, nil, "text"),
            ("user", "这是我的图片，我想看到在公园玩耍的样子", "AvatarUserMsg", "ParkPhoto", nil, "photo"),
            ("ai", "看到你的美照啦！公园的阳光和绿树真的特别有朝气呢，今天的天气也刚好非常适合出门走走，这就给你推荐妆容哈", "AvatarAI", nil, nil, "text"),
            ("ai", "✨ 灵感生成提示：专属的妆容效果已经快马加鞭在生成中啦，", "AvatarAI2", nil, nil, "generating")
        ]

        for (index, item) in demoMessages.enumerated() {
            let (sender, text, avatar, asset, _, kind) = item
            exec(db, sql: """
            INSERT INTO chat_messages (
                id, user_id, sender, text, image_asset_name, image_path,
                ai_avatar_name, message_kind, created_at
            ) VALUES (?, ?, ?, ?, ?, NULL, ?, ?, ?);
            """, bindings: [
                .text("seed_\(index)"),
                .text("mrs_zhang"),
                .text(sender),
                .text(text),
                asset.map { .text($0) } ?? .null,
                .text(avatar),
                .text(kind),
                .double(now + Double(index))
            ])
        }
    }

    private static func exec(_ db: OpaquePointer, sql: String, bindings: [SQLBinding]) {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }

        for (index, binding) in bindings.enumerated() {
            let position = Int32(index + 1)
            switch binding {
            case .text(let value):
                sqlite3_bind_text(statement, position, value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            case .int(let value):
                sqlite3_bind_int(statement, position, Int32(value))
            case .double(let value):
                sqlite3_bind_double(statement, position, value)
            case .null:
                sqlite3_bind_null(statement, position)
            }
        }

        _ = sqlite3_step(statement)
    }
}

private enum SQLBinding {
    case text(String)
    case int(Int)
    case double(Double)
    case null
}
