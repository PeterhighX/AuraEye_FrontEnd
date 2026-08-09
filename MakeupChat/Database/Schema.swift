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
        asset_id TEXT,
        input_sha256 TEXT NOT NULL,
        status TEXT NOT NULL,
        server_request_id TEXT,
        location TEXT,
        retry_after INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY(account_id, capability)
    );
    """

    static let createDemoAssets = """
    CREATE TABLE IF NOT EXISTS demo_assets (
        demo_asset_key TEXT PRIMARY KEY,
        asset_type TEXT NOT NULL,
        local_resource_name TEXT NOT NULL,
        asset_sha256 TEXT NOT NULL,
        dataset_version TEXT NOT NULL,
        remote_asset_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
    );
    """

    static let createDemoRecognitionAttempts = """
    CREATE TABLE IF NOT EXISTS demo_recognition_attempts (
        id TEXT PRIMARY KEY,
        account_id TEXT NOT NULL,
        demo_asset_key TEXT NOT NULL,
        capability TEXT NOT NULL,
        request_id TEXT NOT NULL,
        idempotency_key TEXT,
        job_id TEXT,
        status TEXT NOT NULL,
        server_request_id TEXT,
        location TEXT,
        retry_after INTEGER,
        asset_sha256 TEXT NOT NULL,
        schema_version TEXT NOT NULL,
        model_version TEXT NOT NULL,
        error_code TEXT,
        started_at TEXT NOT NULL,
        completed_at TEXT,
        UNIQUE(account_id, capability, demo_asset_key, asset_sha256, schema_version, model_version)
    );
    """

    static let createDemoResults = """
    CREATE TABLE IF NOT EXISTS demo_results (
        id TEXT PRIMARY KEY,
        account_id TEXT NOT NULL,
        capability TEXT NOT NULL,
        demo_asset_key TEXT NOT NULL,
        asset_sha256 TEXT NOT NULL,
        schema_version TEXT NOT NULL,
        provider_name TEXT,
        model_id TEXT,
        result_source TEXT NOT NULL,
        result_json TEXT NOT NULL,
        generated_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(account_id, capability, demo_asset_key, asset_sha256, schema_version)
    );
    """

    static let migrations: [String] = [
        createUsers,
        createChatMessages,
        createEyeStyles,
        createCosmetics,
        createOnboardingSteps,
        createVisionPendingJobs,
        createDemoAssets,
        createDemoRecognitionAttempts,
        createDemoResults,
        "CREATE INDEX IF NOT EXISTS idx_chat_user_time ON chat_messages(user_id, created_at);",
        "CREATE INDEX IF NOT EXISTS idx_onboarding_user ON onboarding_steps(user_id, step_index);",
        "CREATE INDEX IF NOT EXISTS idx_demo_attempt_lookup ON demo_recognition_attempts(account_id, capability, demo_asset_key);",
        "CREATE INDEX IF NOT EXISTS idx_demo_result_lookup ON demo_results(account_id, capability, demo_asset_key);"
    ]
}
