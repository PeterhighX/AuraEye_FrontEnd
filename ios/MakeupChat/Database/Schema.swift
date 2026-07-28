import Foundation

enum Schema {
    static let createUsers = """
    CREATE TABLE IF NOT EXISTS users (
        user_id TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT '开心',
        credits INTEGER NOT NULL DEFAULT 50,
        user_file TEXT,
        user_portrait TEXT,
        user_update_photo TEXT,
        eye_preview TEXT,
        eye_steps TEXT,
        updated_at REAL NOT NULL
    );
    """

    static let createChatMessages = """
    CREATE TABLE IF NOT EXISTS chat_messages (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        sender TEXT NOT NULL,
        text TEXT NOT NULL,
        image_asset_name TEXT,
        image_path TEXT,
        ai_avatar_name TEXT,
        message_kind TEXT NOT NULL DEFAULT 'text',
        created_at REAL NOT NULL,
        FOREIGN KEY(user_id) REFERENCES users(user_id)
    );
    """

    static let createEyeStyles = """
    CREATE TABLE IF NOT EXISTS eye_styles (
        eye_style_name TEXT PRIMARY KEY,
        eye_svg TEXT,
        eyeliner_name TEXT,
        eyeliner_svg TEXT,
        eye_color_main TEXT,
        eye_color_sub TEXT,
        scene TEXT
    );
    """

    static let createCosmetics = """
    CREATE TABLE IF NOT EXISTS cosmetics (
        sku TEXT PRIMARY KEY,
        makeup_cat TEXT NOT NULL,
        makeup_tab TEXT,
        makeup_colors TEXT,
        brush_json TEXT
    );
    """

    static let migrations: [String] = [
        createUsers,
        createChatMessages,
        createEyeStyles,
        createCosmetics,
        "CREATE INDEX IF NOT EXISTS idx_chat_user_time ON chat_messages(user_id, created_at);"
    ]
}
