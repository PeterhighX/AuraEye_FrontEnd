import Foundation
import Observation

@Observable
final class ProfileViewModel {
    private(set) var user: UserProfile
    private(set) var level: Int = 4
    private(set) var levelProgress: CGFloat = 0.4
    let historyItems: [MakeupHistoryItem] = ProfileViewModel.defaultHistory
    let tasks: [UserTaskItem] = ProfileViewModel.defaultTasks

    private let userRepository: UserRepository

    init(userRepository: UserRepository = UserRepository()) {
        self.userRepository = userRepository
        self.user = UserProfile(
            userId: "mrs_zhang",
            displayName: "Mrs.Zhang",
            status: "开心",
            credits: 50
        )
        reload()
    }

    func reload() {
        if let loaded = try? userRepository.currentUser() {
            user = loaded
        }
    }
}
