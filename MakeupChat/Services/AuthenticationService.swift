import Foundation

struct LoginRequest: Encodable, Sendable {
    let username: String
    let password: String
    let requestId: String

    init(
        username: String,
        password: String,
        requestID: String = Self.makeRequestID()
    ) {
        self.username = username
        self.password = password
        self.requestId = requestID
    }

    enum CodingKeys: String, CodingKey {
        case username, password
        case requestId = "request_id"
    }

    static func makeRequestID() -> String {
        "req_login_\(UUID().uuidString.lowercased())"
    }
}

struct RefreshTokenRequest: Encodable, Sendable {
    let refreshToken: String
    let requestId: String

    init(refreshToken: String, requestID: String = LoginRequest.makeRequestID()) {
        self.refreshToken = refreshToken
        self.requestId = requestID
    }

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
        case requestId = "request_id"
    }
}

struct LogoutRequest: Encodable, Sendable {
    let refreshToken: String
    let requestId: String

    init(refreshToken: String, requestID: String = LoginRequest.makeRequestID()) {
        self.refreshToken = refreshToken
        self.requestId = requestID
    }

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
        case requestId = "request_id"
    }
}

struct LogoutResponseDTO: Decodable, Sendable {
    let revoked: Bool

    enum CodingKeys: String, CodingKey {
        case revoked
    }
}

enum AccountMode: String, Codable, Sendable {
    case standard
    case demo
}

enum GalleryMode: String, Codable, Sendable {
    case fixedDemo = "fixed_demo"
    case authorizedLibrary = "authorized_library"

    var allowsCameraCapture: Bool {
        self == .authorizedLibrary
    }
}

struct AccountFeatures: Codable, Equatable, Sendable {
    let galleryMode: GalleryMode
    let useDemoAssets: Bool
    let allowLiveRecognitionSeed: Bool

    enum CodingKeys: String, CodingKey {
        case galleryMode = "gallery_mode"
        case useDemoAssets = "use_demo_assets"
        case allowLiveRecognitionSeed = "allow_live_recognition_seed"
    }

    static let standard = AccountFeatures(
        galleryMode: .authorizedLibrary,
        useDemoAssets: false,
        allowLiveRecognitionSeed: false
    )

    static let demo = AccountFeatures(
        galleryMode: .fixedDemo,
        useDemoAssets: true,
        allowLiveRecognitionSeed: false
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
            accountMode = try user.decodeIfPresent(AccountMode.self, forKey: .accountMode) ?? .standard
        } else {
            userId = try container.decode(String.self, forKey: .userId)
            username = try container.decodeIfPresent(String.self, forKey: .username)
                ?? container.decodeIfPresent(String.self, forKey: .displayName)
                ?? userId
            displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? username
            accountMode = try container.decodeIfPresent(AccountMode.self, forKey: .accountMode) ?? .standard
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

    func applyingServerFeatures(_ features: AccountFeatures) -> AuthenticatedAccount {
        AuthenticatedAccount(
            userId: userId,
            username: username,
            displayName: displayName,
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            accountMode: accountMode,
            features: features
        )
    }

}

struct AuthMeFeatureDTO: Decodable, Sendable {
    let features: AccountFeatures
}

protocol AuthenticationServicing {
    func login(account: String, password: String) async throws -> AuthenticatedAccount
}

@MainActor
enum AuthenticationServiceFactory {
    /// 普通 Debug、联调和 Release 都只使用显式配置的远端认证。
    static func makeDefault(bundle: Bundle = .main) -> any AuthenticationServicing {
#if AURAEYE_ENABLE_LOCAL_AUTH_STUB
        return LocalInternalAuthenticationService()
#else
        do {
            let configuration = try APIEnvironment.shared.load(bundle: bundle)
            return RemoteAuthenticationService(client: APIClient(configuration: configuration))
        } catch let error as APIConfigurationError {
            return UnavailableAuthenticationService(error: error)
        } catch {
            return UnavailableAuthenticationService(error: .configurationInvalid("unknown"))
        }
#endif
    }
}

private struct UnavailableAuthenticationService: AuthenticationServicing {
    let error: APIConfigurationError

    func login(account: String, password: String) async throws -> AuthenticatedAccount {
        throw error
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

/// 仅供显式启用 `AURAEYE_ENABLE_LOCAL_AUTH_STUB` 的独立本地 Scheme 使用。
struct LocalInternalAuthenticationService: AuthenticationServicing {
    static let testAccount = "aurayetest"
    static let testPassword = "AuraEye2026"

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
