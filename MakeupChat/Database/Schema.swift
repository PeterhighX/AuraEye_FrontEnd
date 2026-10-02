import Foundation

enum Schema {
    static let createUsers = """
    CREATE TABLE IF NOT EXISTS users (
        user_id TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT '开心',
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
        reply_type TEXT NOT NULL DEFAULT 'text',
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

    static let createChatAttachments = """
    CREATE TABLE IF NOT EXISTS chat_attachments (
        id TEXT PRIMARY KEY,
        message_id TEXT NOT NULL,
        type TEXT NOT NULL,
        source TEXT NOT NULL,
        thumbnail_url TEXT NOT NULL,
        content_url TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        width INTEGER NOT NULL,
        height INTEGER NOT NULL,
        expires_at REAL,
        local_thumbnail_path TEXT,
        local_content_path TEXT,
        created_at REAL NOT NULL,
        updated_at REAL NOT NULL,
        FOREIGN KEY(message_id) REFERENCES chat_messages(id) ON DELETE CASCADE
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
        createOnboardingSteps,
        createVisionPendingJobs,
        "CREATE INDEX IF NOT EXISTS idx_onboarding_user ON onboarding_steps(user_id, step_index);",
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_vision_pending_idempotency ON vision_pending_jobs(account_id, capability, idempotency_key) WHERE idempotency_key IS NOT NULL;"
    ]
}
