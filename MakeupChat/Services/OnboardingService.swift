import Foundation
import UIKit

/// 第一次使用的页面进度暂存；档案和已确认商品以服务端为准。
@MainActor
final class OnboardingService {
    private let userRepository: UserRepository
    private let onboardingRepository: OnboardingRepository
    private let recognitionService: any CosmeticsRecognitionServicing
    private let faceAnalysisService: any FaceAnalysisServicing

    init(
        userRepository: UserRepository = UserRepository(),
        onboardingRepository: OnboardingRepository = OnboardingRepository(),
        recognitionService: any CosmeticsRecognitionServicing = AccountAwareCosmeticsRecognitionService(),
        faceAnalysisService: any FaceAnalysisServicing = AccountAwareFaceAnalysisService()
    ) {
        self.userRepository = userRepository
        self.onboardingRepository = onboardingRepository
        self.recognitionService = recognitionService
        self.faceAnalysisService = faceAnalysisService
    }

    static func demoSteps(from run: DemoRunDTO, userID: String) -> [OnboardingStep] {
        let completed = run.completed
        let cosmeticSteps = ["eyeshadow_recognition", "eyeliner_recognition", "brush_recognition"]
        let cosmeticCount = cosmeticSteps.filter { completed.contains($0) }.count
        let nextCosmetic: String
        switch run.nextStep {
        case "eyeshadow_recognition": nextCosmetic = "眼影盘"
        case "eyeliner_recognition": nextCosmetic = "眼线笔"
        case "brush_recognition": nextCosmetic = "化妆刷"
        default: nextCosmetic = "化妆品"
        }
        let faceDone = completed.contains("face_analysis")
        let cosmeticsDone = cosmeticCount == cosmeticSteps.count
        let planDone = completed.contains("makeup_plan") || completed.contains("makeup_practice")
        return OnboardingStepKey.allCases.map { key in
            let status: OnboardingStepStatus
            let subtitle: String
            switch key {
            case .userProfile:
                status = faceDone ? .completed : .inProgress
                subtitle = key.defaultSubtitle
            case .cosmetics:
                status = cosmeticsDone ? .completed : (faceDone ? .inProgress : .pending)
                subtitle = "✨ 本轮已确认 \(cosmeticCount)/3 类，接下来识别\(nextCosmetic)"
            case .makeupGenerate:
                status = planDone ? .completed : (cosmeticsDone ? .inProgress : .pending)
                subtitle = key.defaultSubtitle
            }
            return OnboardingStep(
                id: "demo_\(run.runID)_\(key.rawValue)", userId: userID,
                stepKey: key, status: status, subtitle: subtitle,
                previewAsset: key.defaultPreviewAsset, previewPath: nil, updatedAt: .now
            )
        }
    }

    func loadSteps() throws -> (UserProfile, [OnboardingStep]) {
        let user = try userRepository.currentUser()
        try onboardingRepository.ensureDefaultSteps(userId: user.userId)
        let steps = try onboardingRepository.fetchSteps(userId: user.userId)
        return (user, steps)
    }

    /// 将本次启动中从其他入口已经完成的建档/入柜结果同步到引导流程。
    func resumeExistingInputs(
        faceImagePath: String?,
        hasVisualProfile: Bool,
        cosmetics: [CosmeticDTO]
    ) throws -> [OnboardingStep] {
        let user = try userRepository.currentUser()

        if hasVisualProfile {
            try onboardingRepository.updateStep(
                userId: user.userId,
                key: .userProfile,
                status: .completed,
                subtitle: OnboardingStepKey.userProfile.completedSubtitle,
                previewPath: faceImagePath
            )
            try onboardingRepository.activateNextStep(after: .userProfile, userId: user.userId)
        } else {
            try onboardingRepository.updateStep(
                userId: user.userId, key: .userProfile, status: .inProgress,
                subtitle: OnboardingStepKey.userProfile.defaultSubtitle
            )
            try onboardingRepository.updateStep(
                userId: user.userId, key: .makeupGenerate, status: .pending
            )
        }

        let categorySet = Set(cosmetics.compactMap {
            CosmeticCategory.from(raw: $0.category)
        })
        let hasAllRequiredCosmetics = categorySet.isSuperset(of: Set(CosmeticCategory.allCases))

        if hasAllRequiredCosmetics {
            try onboardingRepository.updateStep(
                userId: user.userId,
                key: .cosmetics,
                status: .completed,
                subtitle: OnboardingStepKey.cosmetics.completedSubtitle,
                previewPath: nil
            )
            // 化妆品可以先于档案添加；只有脸部也已完成时才开放 Step 3。
            if hasVisualProfile {
                try onboardingRepository.activateNextStep(after: .cosmetics, userId: user.userId)
            }
        } else if !hasAllRequiredCosmetics {
            try onboardingRepository.updateStep(
                userId: user.userId,
                key: .cosmetics,
                status: hasVisualProfile ? .inProgress : .pending,
                subtitle: OnboardingStepKey.cosmetics.defaultSubtitle
            )
            try onboardingRepository.updateStep(
                userId: user.userId,
                key: .makeupGenerate,
                status: .pending
            )
        }

        return try onboardingRepository.fetchSteps(userId: user.userId)
    }

    func completeFaceScan(image: UIImage) async throws -> [OnboardingStep] {
        try await completeFaceScan(input: VisionImageInput(image: image))
    }

    func completeFaceScan(input: VisionImageInput) async throws -> [OnboardingStep] {
        let user = try userRepository.currentUser()
        let analysis = try await faceAnalysisService.analyze(
            input: input,
            userId: user.userId
        )

        var profile = user
        profile.userPortraitPath = analysis.portraitPath
        profile.userFileJSON = analysis.profileJSON
        try userRepository.update(profile)

        if SessionManager.shared.context?.accountMode == .demo { return [] }

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
        try await recognizeCosmetics(input: VisionImageInput(image: image))
    }

    func recognizeCosmetics(input: VisionImageInput) async throws -> CosmeticsRecognitionResult {
        let result = try await recognitionService.recognize(
            input: input,
            categoryHint: nil
        )
        guard result.hasRequiredProductInformation else {
            throw CosmeticsRecognitionError.incompleteProductInformation
        }
        return result
    }

    func completeCosmeticsScan(result: CosmeticsRecognitionResult, requestID: String) async throws -> [OnboardingStep] {
        let user = try userRepository.currentUser()
        _ = try await BusinessDataService.shared.addCosmetic(result, requestID: requestID)
        await BusinessStore.shared.refreshCosmetics()
        if let error = BusinessStore.shared.cosmeticsError {
            throw NSError(domain: "AuraEyeCosmetics", code: 1, userInfo: [NSLocalizedDescriptionKey: error])
        }

        if SessionManager.shared.context?.accountMode == .demo { return [] }

        let categories = Set(
            BusinessStore.shared.cosmetics.compactMap { CosmeticCategory.from(raw: $0.category) }
        )
        let isComplete = categories.isSuperset(of: Set(CosmeticCategory.allCases))

        try onboardingRepository.updateStep(
            userId: user.userId,
            key: .cosmetics,
            status: isComplete ? .completed : .inProgress,
            subtitle: isComplete
                ? OnboardingStepKey.cosmetics.completedSubtitle
                : "✨ 已添加 \(categories.count)/3 类化妆品，请继续添加",
            previewPath: result.previewPath
        )
        if isComplete {
            try onboardingRepository.activateNextStep(after: .cosmetics, userId: user.userId)
        } else {
            try onboardingRepository.updateStep(
                userId: user.userId,
                key: .makeupGenerate,
                status: .pending
            )
        }

        return try onboardingRepository.fetchSteps(userId: user.userId)
    }

}
