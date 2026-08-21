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
        conversation_id TEXT,
        sender TEXT NOT NULL,
        text TEXT NOT NULL,
        ai_avatar_name TEXT,
        client_request_id TEXT,
        server_message_id TEXT,
        server_request_id TEXT,
        delivery_status TEXT NOT NULL DEFAULT 'completed',
        error_code TEXT,
        error_detail TEXT,
        http_status INTEGER,
        created_at REAL NOT NULL,
        updated_at REAL NOT NULL DEFAULT 0,
        FOREIGN KEY(user_id) REFERENCES users(user_id)
    );
    """

    static let createChatConversations = """
    CREATE TABLE IF NOT EXISTS chat_conversations (
        user_id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL UNIQUE,
        created_at REAL NOT NULL,
        updated_at REAL NOT NULL,
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
        user_id TEXT,
        makeup_cat TEXT NOT NULL,
        makeup_tab TEXT,
        makeup_colors TEXT,
        brush_json TEXT,
        preview_asset TEXT,
        preview_path TEXT,
        scanned_at REAL
    );
    """

    static let createOnboardingSteps = """
    CREATE TABLE IF NOT EXISTS onboarding_steps (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        step_key TEXT NOT NULL,
        step_index INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        subtitle TEXT,
        preview_asset TEXT,
        preview_path TEXT,
        updated_at REAL NOT NULL,
        UNIQUE(user_id, step_key),
        FOREIGN KEY(user_id) REFERENCES users(user_id)
    );
    """

    static let createVisionPendingJobs = """
    CREATE TABLE IF NOT EXISTS vision_pending_jobs (
        account_id TEXT NOT NULL,
        capability TEXT NOT NULL,
        request_id TEXT NOT NULL,
        idempotency_key TEXT,
        job_id TEXT,
        status TEXT NOT NULL,
        server_request_id TEXT,
        location TEXT,
        retry_after INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY(account_id, capability)
    );
    """

    static let migrations: [String] = [
        createUsers,
        createChatMessages,
        createChatConversations,
        createEyeStyles,
        createCosmetics,
        createOnboardingSteps,
        createVisionPendingJobs,
        "CREATE INDEX IF NOT EXISTS idx_onboarding_user ON onboarding_steps(user_id, step_index);",
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_vision_pending_idempotency ON vision_pending_jobs(account_id, capability, idempotency_key) WHERE idempotency_key IS NOT NULL;"
    ]
}
