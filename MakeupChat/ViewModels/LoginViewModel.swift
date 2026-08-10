import Foundation
import Observation

@Observable
@MainActor
final class LoginViewModel {
    var account: String
    var password: String
    private(set) var isLoggingIn = false
    private(set) var errorMessage: String?

    private let authenticationService: any AuthenticationServicing

    init(
        authenticationService: (any AuthenticationServicing)? = nil,
        initialAccount: String = LocalInternalAuthenticationService.testAccount,
        initialPassword: String = LocalInternalAuthenticationService.testPassword
    ) {
        self.authenticationService = authenticationService ?? AuthenticationServiceFactory.makeDefault()
        account = initialAccount
        password = initialPassword
    }

    func login() async -> AuthenticatedAccount? {
        guard !isLoggingIn else { return nil }
        isLoggingIn = true
        errorMessage = nil
        defer { isLoggingIn = false }

        do {
            return try await authenticationService.login(
                account: account,
                password: password
            )
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
