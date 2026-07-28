import Foundation
import Observation
import UIKit

@Observable
final class UserProfileSetupViewModel {
    private(set) var isAnalyzing = false
    private(set) var errorMessage: String?

    private let analysisService: FaceAnalysisServicing
    private let userRepository: UserRepository

    init(
        analysisService: FaceAnalysisServicing = LocalFaceAnalysisService(),
        userRepository: UserRepository = UserRepository()
    ) {
        self.analysisService = analysisService
        self.userRepository = userRepository
    }

    func analyze(_ image: UIImage, session: AppSession) async -> Bool {
        guard !isAnalyzing else { return false }
        isAnalyzing = true
        errorMessage = nil
        defer { isAnalyzing = false }

        do {
            var user = try userRepository.currentUser()
            let result = try await analysisService.analyze(
                image: image,
                userId: user.userId
            )

            user.userPortraitPath = result.portraitPath
            user.userFileJSON = result.profileJSON
            try userRepository.update(user)
            session.markFaceScanned(imagePath: result.portraitPath)
            return true
        } catch {
            errorMessage = "面部分析暂时未完成，请重新选择照片。"
            return false
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
