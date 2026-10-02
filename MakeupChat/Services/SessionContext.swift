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
    private var demoRun: (accountID: String, value: DemoRunDTO)?

    private init() {}

    func establish(account: AuthenticatedAccount) {
        if context?.userId != account.userId || context?.accountMode != account.accountMode {
            demoRun = nil
        }
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
        demoRun = nil
    }

    func installDemoRun(_ run: DemoRunDTO, for accountID: String) {
        guard context?.accountMode == .demo, context?.userId == accountID else { return }
        demoRun = (accountID, run)
    }

    func clearDemoRun() {
        demoRun = nil
    }

    func currentDemoRunID() throws -> String? {
        guard let context else { return nil }
        guard context.accountMode == .demo else { return nil }
        guard let demoRun, demoRun.accountID == context.userId else {
            throw DemoRunError.unavailable
        }
        return demoRun.value.runID
    }

    func currentDemoRun() throws -> DemoRunDTO? {
        guard let context else { return nil }
        guard context.accountMode == .demo else { return nil }
        guard let demoRun, demoRun.accountID == context.userId else {
            throw DemoRunError.unavailable
        }
        return demoRun.value
    }
}
