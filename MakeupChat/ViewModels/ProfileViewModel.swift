import Foundation
import Observation

@Observable
@MainActor
final class ProfileViewModel {
    private(set) var user: UserProfile
    private let userRepository: UserRepository

    init(userRepository: UserRepository = UserRepository()) {
        self.userRepository = userRepository
        self.user = UserProfile(
            userId: SessionManager.shared.context?.userId ?? "",
            displayName: SessionManager.shared.context?.displayName ?? "用户",
            status: ""
        )
        reload()
    }

    func reload() {
        if let loaded = try? userRepository.currentUser() {
            user = loaded
        }
    }
}
