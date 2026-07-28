import Foundation
import UIKit

/// 第一次使用流程 — 本地 Repository 编排（无云端）
final class OnboardingService {
    private let userRepository: UserRepository
    private let onboardingRepository: OnboardingRepository
    private let eyeStyleRepository: EyeStyleRepository
    private let cosmeticsRepository: CosmeticsRepository
    private let recognitionService: any CosmeticsRecognitionServicing
    private let faceAnalysisService: any FaceAnalysisServicing

    init(
        userRepository: UserRepository = UserRepository(),
        onboardingRepository: OnboardingRepository = OnboardingRepository(),
        eyeStyleRepository: EyeStyleRepository = EyeStyleRepository(),
        cosmeticsRepository: CosmeticsRepository = CosmeticsRepository(),
        recognitionService: any CosmeticsRecognitionServicing = CosmeticsRecognitionService(),
        faceAnalysisService: any FaceAnalysisServicing = LocalFaceAnalysisService()
    ) {
        self.userRepository = userRepository
        self.onboardingRepository = onboardingRepository
        self.eyeStyleRepository = eyeStyleRepository
        self.cosmeticsRepository = cosmeticsRepository
        self.recognitionService = recognitionService
        self.faceAnalysisService = faceAnalysisService
    }

    func loadSteps() throws -> (UserProfile, [OnboardingStep]) {
        let user = try userRepository.currentUser()
        try onboardingRepository.ensureDefaultSteps(userId: user.userId)
        let steps = try onboardingRepository.fetchSteps(userId: user.userId)
        return (user, steps)
    }

    func resetStepsForNewLaunch() throws {
        let user = try userRepository.currentUser()
        try onboardingRepository.ensureDefaultSteps(userId: user.userId)
        try onboardingRepository.resetForNewLaunch(userId: user.userId)
    }

    /// 将本次启动中从其他入口已经完成的建档/入柜结果同步到引导流程。
    func resumeExistingInputs(
        faceImagePath: String?,
        hasCosmetics: Bool
    ) throws -> [OnboardingStep] {
        let user = try userRepository.currentUser()

        if let faceImagePath, !faceImagePath.isEmpty {
            try onboardingRepository.updateStep(
                userId: user.userId,
                key: .userProfile,
                status: .completed,
                subtitle: OnboardingStepKey.userProfile.completedSubtitle,
                previewPath: faceImagePath
            )
            try onboardingRepository.activateNextStep(after: .userProfile, userId: user.userId)
        }

        if faceImagePath?.isEmpty == false,
           hasCosmetics,
           let product = try cosmeticsRepository.fetchAll(userId: user.userId).first {
            try onboardingRepository.updateStep(
                userId: user.userId,
                key: .cosmetics,
                status: .completed,
                subtitle: OnboardingStepKey.cosmetics.completedSubtitle,
                previewPath: product.previewPath
            )
            try onboardingRepository.activateNextStep(after: .cosmetics, userId: user.userId)
        }

        return try onboardingRepository.fetchSteps(userId: user.userId)
    }

    func completeFaceScan(image: UIImage) async throws -> [OnboardingStep] {
        let user = try userRepository.currentUser()
        let analysis = try await faceAnalysisService.analyze(
            image: image,
            userId: user.userId
        )

        var profile = user
        profile.userPortraitPath = analysis.portraitPath
        profile.userFileJSON = analysis.profileJSON
        try userRepository.update(profile)

        try onboardingRepository.updateStep(
            userId: user.userId,
            key: .userProfile,
            status: .completed,
            subtitle: OnboardingStepKey.userProfile.completedSubtitle,
            previewPath: analysis.portraitPath
        )
        try onboardingRepository.activateNextStep(after: .userProfile, userId: user.userId)

        return try onboardingRepository.fetchSteps(userId: user.userId)
    }

    func recognizeCosmetics(image: UIImage) async throws -> CosmeticsRecognitionResult {
        try await recognitionService.recognize(
            image: image,
            categoryHint: nil
        )
    }

    func completeCosmeticsScan(result: CosmeticsRecognitionResult) throws -> [OnboardingStep] {
        let user = try userRepository.currentUser()
        try cosmeticsRepository.insertRecognized(userId: user.userId, result: result)

        try onboardingRepository.updateStep(
            userId: user.userId,
            key: .cosmetics,
            status: .completed,
            subtitle: OnboardingStepKey.cosmetics.completedSubtitle,
            previewPath: result.previewPath
        )
        try onboardingRepository.activateNextStep(after: .cosmetics, userId: user.userId)

        return try onboardingRepository.fetchSteps(userId: user.userId)
    }

    func generateMakeup() async throws -> [OnboardingStep] {
        let user = try userRepository.currentUser()

        try onboardingRepository.updateStep(
            userId: user.userId,
            key: .makeupGenerate,
            status: .inProgress,
            subtitle: "✨ 专属妆容效果正在生成中……"
        )

        try await Task.sleep(for: .seconds(1.2))

        let style = try eyeStyleRepository.fetch(scene: "日常")
        let previewPath = try persistMakeupPreview(style: style, userId: user.userId)
        let stepsJSON = "[\"step_eye.svg\",\"step_liner.svg\",\"step_blush.svg\"]"

        try userRepository.updateEyePreview(
            userId: user.userId,
            previewPath: previewPath,
            stepsJSON: stepsJSON
        )

        let stepPreviewPath = try makeupStepPreviewPath(
            userId: user.userId,
            portraitPath: user.userPortraitPath,
            style: style
        )

        try onboardingRepository.updateStep(
            userId: user.userId,
            key: .makeupGenerate,
            status: .completed,
            subtitle: OnboardingStepKey.makeupGenerate.completedSubtitle,
            previewPath: stepPreviewPath
        )

        return try onboardingRepository.fetchSteps(userId: user.userId)
    }

    /// 步骤卡片左侧预览图：优先复用面部扫描图，否则生成妆容预览占位图
    private func makeupStepPreviewPath(
        userId: String,
        portraitPath: String?,
        style: EyeStyle?
    ) throws -> String {
        if let portraitPath,
           LocalMediaStore.loadImage(fromStoredPath: portraitPath) != nil {
            return portraitPath
        }

        let image = MakeupPreviewThumbnailRenderer.render(style: style)
        return try LocalMediaStore.saveImage(
            image,
            bucket: .makeupPreviews,
            fileName: "makeup_step_preview_\(userId).jpg"
        )
    }

    private func persistMakeupPreview(style: EyeStyle?, userId: String) throws -> String {
        let name = style?.eyeStyleName ?? "default_look"
        let content = """
        eye_style=\(name)
        scene=\(style?.scene ?? "日常")
        main=\(style?.eyeColorMain ?? "#C4A484")
        sub=\(style?.eyeColorSub ?? "#8B7355")
        """
        return try LocalMediaStore.saveText(
            content,
            bucket: .makeupPreviews,
            fileName: "makeup_preview_\(userId)_\(name).json"
        )
    }
}
