import Foundation

struct LoginRequest: Encodable, Sendable {
    let account: String
    let password: String
}

enum AccountMode: String, Codable, Sendable {
    case standard
    case demo
}

struct AccountFeatures: Codable, Equatable, Sendable {
    let useDemoAssets: Bool
    let allowLiveRecognitionSeed: Bool

    enum CodingKeys: String, CodingKey {
        case useDemoAssets = "use_demo_assets"
        case allowLiveRecognitionSeed = "allow_live_recognition_seed"
    }

    static let standard = AccountFeatures(
        useDemoAssets: false,
        allowLiveRecognitionSeed: false
    )

    static let demo = AccountFeatures(
        useDemoAssets: true,
        allowLiveRecognitionSeed: true
    )
}

struct AuthenticatedAccount: Codable, Equatable, Sendable {
    let userId: String
    let username: String
    let displayName: String
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date?
    let accountMode: AccountMode
    let features: AccountFeatures

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case displayName = "display_name"
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case accessTokenExpiresAt = "access_token_expires_at"
        case accountMode = "account_mode"
        case features
        case user
    }

    private enum UserCodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case accountMode = "account_mode"
    }

    init(
        userId: String,
        username: String,
        displayName: String,
        accessToken: String,
        refreshToken: String? = nil,
        expiresAt: Date?,
        accountMode: AccountMode,
        features: AccountFeatures
    ) {
        self.userId = userId
        self.username = username
        self.displayName = displayName
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.accountMode = accountMode
        self.features = features
    }

    /// 同时兼容方案中的嵌套 `user` 响应和旧版扁平登录响应。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try container.decode(String.self, forKey: .accessToken)
        refreshToken = try container.decodeIfPresent(String.self, forKey: .refreshToken)
        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
            ?? container.decodeIfPresent(Date.self, forKey: .accessTokenExpiresAt)
        let decodedFeatures = try container.decodeIfPresent(AccountFeatures.self, forKey: .features)

        if container.contains(.user) {
            let user = try container.nestedContainer(keyedBy: UserCodingKeys.self, forKey: .user)
            userId = try user.decode(String.self, forKey: .id)
            username = try user.decode(String.self, forKey: .username)
            displayName = try user.decodeIfPresent(String.self, forKey: .displayName) ?? username
            accountMode = try user.decodeIfPresent(AccountMode.self, forKey: .accountMode)
                ?? Self.temporaryMode(username: username)
        } else {
            userId = try container.decode(String.self, forKey: .userId)
            username = try container.decodeIfPresent(String.self, forKey: .username)
                ?? container.decodeIfPresent(String.self, forKey: .displayName)
                ?? userId
            displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? username
            accountMode = try container.decodeIfPresent(AccountMode.self, forKey: .accountMode)
                ?? Self.temporaryMode(username: username)
        }
        features = decodedFeatures ?? (accountMode == .demo ? .demo : .standard)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encode(username, forKey: .username)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(accessToken, forKey: .accessToken)
        try container.encodeIfPresent(refreshToken, forKey: .refreshToken)
        try container.encodeIfPresent(expiresAt, forKey: .expiresAt)
        try container.encode(accountMode, forKey: .accountMode)
        try container.encode(features, forKey: .features)
    }

    private static func temporaryMode(username: String) -> AccountMode {
        username.caseInsensitiveCompare(LocalInternalAuthenticationService.testAccount) == .orderedSame
            ? .demo
            : .standard
    }
}

protocol AuthenticationServicing {
    func login(account: String, password: String) async throws -> AuthenticatedAccount
}

enum AuthenticationServiceFactory {
    /// 配置了 API_BASE_URL 时使用后端登录；纯前端演示构建才回退到本地测试账号。
    static func makeDefault(bundle: Bundle = .main) -> any AuthenticationServicing {
        guard let configuration = try? APIConfiguration.fromBundle(bundle) else {
            return LocalInternalAuthenticationService()
        }
        return RemoteAuthenticationService(client: APIClient(configuration: configuration))
    }
}

enum AuthenticationError: LocalizedError {
    case emptyCredentials
    case invalidCredentials

    var errorDescription: String? {
        switch self {
        case .emptyCredentials:
            return "请输入账号和密码。"
        case .invalidCredentials:
            return "账号或密码不正确，请重新输入。"
        }
    }
}

/// 后端登录接口启用前的本地账号验证服务。
/// 正式构建应注入 `RemoteAuthenticationService`。
struct LocalInternalAuthenticationService: AuthenticationServicing {
    static let testAccount = "aurayetest"
    static let testPassword = "AuraAye2026"

    func login(account: String, password: String) async throws -> AuthenticatedAccount {
        let normalizedAccount = account.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedAccount.isEmpty, !password.isEmpty else {
            throw AuthenticationError.emptyCredentials
        }

        try await Task.sleep(for: .milliseconds(520))
        guard normalizedAccount == Self.testAccount,
              password == Self.testPassword else {
            throw AuthenticationError.invalidCredentials
        }

        return AuthenticatedAccount(
            userId: "mrs_zhang",
            username: normalizedAccount,
            displayName: "Mrs.Zhang",
            accessToken: "local-internal-test-token",
            expiresAt: nil,
            accountMode: .demo,
            features: .demo
        )
    }
}
