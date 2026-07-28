import Foundation
import Observation

@Observable
final class HomeViewModel {
    private(set) var user: UserProfile
    private(set) var recommendedScenes: [EyeStyle] = []

    private let userRepository: UserRepository
    private let eyeStyleRepository: EyeStyleRepository

    init(
        userRepository: UserRepository = UserRepository(),
        eyeStyleRepository: EyeStyleRepository = EyeStyleRepository()
    ) {
        self.userRepository = userRepository
        self.eyeStyleRepository = eyeStyleRepository
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
        recommendedScenes = (try? eyeStyleRepository.fetchAll()) ?? []
    }
}
