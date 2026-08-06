import Foundation
import Observation
import UIKit

@Observable
@MainActor
final class UserProfileSetupViewModel {
    private(set) var isAnalyzing = false
    private(set) var errorMessage: String?
    private(set) var analysisState: AsyncAnalysisState<FaceAnalysisResult> = .idle

    private let analysisService: FaceAnalysisServicing
    private let userRepository: UserRepository

    init(
        analysisService: FaceAnalysisServicing = AccountAwareFaceAnalysisService(),
        userRepository: UserRepository = UserRepository()
    ) {
        self.analysisService = analysisService
        self.userRepository = userRepository
    }

    func analyze(_ image: UIImage, session: AppSession) async -> Bool {
        guard !isAnalyzing else { return false }
        isAnalyzing = true
        analysisState = .preparingImage
        errorMessage = nil
        defer { isAnalyzing = false }

        do {
            analysisState = .submitting
            var user = try userRepository.currentUser()
            analysisState = .processing(stage: "visual_profile")
            let result = try await analysisService.analyze(
                image: image,
                userId: user.userId
            )

            user.userPortraitPath = result.portraitPath
            user.userFileJSON = result.profileJSON
            try userRepository.update(user)
            session.markFaceScanned(imagePath: result.portraitPath)
            analysisState = .succeeded(result)
            return true
        } catch let error as VisionAPIError {
            analysisState = .failed(error)
            errorMessage = error.localizedDescription
            return false
        } catch let error as FaceAnalysisError {
            analysisState = .failed(.resultInvalid)
            errorMessage = error.localizedDescription
            return false
        } catch {
            analysisState = .failed(.resultInvalid)
            errorMessage = "面部分析暂时未完成，请重新选择照片。"
            return false
        }
    }

    func clearError() {
        errorMessage = nil
        if case .failed = analysisState { analysisState = .idle }
    }
}
