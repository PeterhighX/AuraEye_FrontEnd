import Foundation
import Observation

struct SessionContext: Equatable, Sendable {
    let userId: String
    let username: String
    let displayName: String
    let accountMode: AccountMode
    let features: AccountFeatures
    let accessToken: String
    let refreshToken: String?
}

/// 账号模式的唯一判断入口。页面、ViewModel 和具体 Provider 不检查用户名。
@Observable
@MainActor
final class SessionManager {
    static let shared = SessionManager()

    private(set) var context: SessionContext?

    private init() {}

    func establish(account: AuthenticatedAccount) {
        context = SessionContext(
            userId: account.userId,
            username: account.username,
            displayName: account.displayName,
            accountMode: account.accountMode,
            features: account.features,
            accessToken: account.accessToken,
            refreshToken: account.refreshToken
        )
    }

    func clear() {
        context = nil
    }
}
