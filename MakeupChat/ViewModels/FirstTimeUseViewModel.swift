import Foundation
import Observation
import UIKit

enum OnboardingCameraTarget: Equatable {
    case face
    case cosmetics
}

enum PendingNavigation: Equatable {
    case none
    case onboardingCabinet
    case makeupPreview
}

enum OnboardingProcessingStage: Equatable {
    case none
    case profile
    case cosmetics
    case makeup
}

@Observable
@MainActor
final class FirstTimeUseViewModel {
    private(set) var steps: [OnboardingStep] = []
    private(set) var statusText = "扫描脸部，建立用户档案中……"
    private(set) var isProcessing = false
    private(set) var hasStartedProgress = false
    private(set) var preparationProgress = 0.0
    private(set) var profileAnalysisProgress = 0.0
    private(set) var pendingProduct: CosmeticsRecognitionResult?
    private(set) var pendingNavigation: PendingNavigation = .none
    private(set) var processingStage: OnboardingProcessingStage = .none
    private(set) var recognitionErrorTitle = "未识别到化妆品"
    private(set) var recognitionErrorMessage: String?

    var showsCaptureProgress: Bool {
        isProcessing && processingStage == .profile
    }

    var cameraTarget: OnboardingCameraTarget = .face

    private let service: OnboardingService
    private let session: AppSession

    init(service: OnboardingService = OnboardingService(), session: AppSession) {
        self.service = service
        self.session = session
    }

    func reload() {
        do {
            if !session.hasResetOnboardingThisLaunch {
                try service.resetStepsForNewLaunch()
                session.hasResetOnboardingThisLaunch = true
                hasStartedProgress = false
                preparationProgress = 0
            }
            let (_, loaded) = try service.loadSteps()
            steps = completeThreeStepSet(from: loaded)
            if session.hasScannedFace || session.hasAddedCosmetics {
                steps = completeThreeStepSet(from: try service.resumeExistingInputs(
                    faceImagePath: session.scannedFaceImagePath,
                    hasCosmetics: session.hasCompletedOnboardingCosmeticsStep
                ))
                if session.hasScannedFace {
                    hasStartedProgress = true
                    preparationProgress = session.hasCompletedOnboardingCosmeticsStep ? 1 : 0.5
                }
            }
            syncSessionFromSteps()
            updateStatusText()
        } catch {
            // 数据库临时不可用时仍保证首次使用页面固定呈现完整三步骤。
            steps = OnboardingStepKey.allCases.map { key in
                OnboardingStep(
                    id: "fallback_\(key.rawValue)",
                    userId: "mrs_zhang",
                    stepKey: key,
                    status: key == .userProfile ? .inProgress : .pending,
                    subtitle: key.defaultSubtitle,
                    previewAsset: key.defaultPreviewAsset,
                    previewPath: nil,
                    updatedAt: Date()
                )
            }
        }
    }

    private func completeThreeStepSet(from loaded: [OnboardingStep]) -> [OnboardingStep] {
        OnboardingStepKey.allCases.map { key in
            if var existing = loaded.first(where: { $0.stepKey == key }) {
                // 数据库可能仍保存旧资源名；每次加载都以当前设计规范为准。
                // Step 2 / Step 3 随后由 StepPreviewThumbnail 固定优先显示这些 SVG。
                existing.previewAsset = key.defaultPreviewAsset
                return existing
            }
            return OnboardingStep(
                id: "fallback_\(key.rawValue)",
                userId: "mrs_zhang",
                stepKey: key,
                status: key == .userProfile ? .inProgress : .pending,
                subtitle: key.defaultSubtitle,
                previewAsset: key.defaultPreviewAsset,
                previewPath: nil,
                updatedAt: Date()
            )
        }
    }

    func handleCameraCapture(_ image: UIImage) {
        Task {
            await handleSelectedInput(VisionImageInput(image: image))
        }
    }

    func handleSelectedInput(_ input: VisionImageInput) async {
        recognitionErrorMessage = nil
        recognitionErrorTitle = "未识别到化妆品"
        isProcessing = true
        hasStartedProgress = true
        preparationProgress = max(preparationProgress, 0.08)
        processingStage = cameraTarget == .face ? .profile : .cosmetics
        defer {
            isProcessing = false
            processingStage = .none
        }
        do {
                switch cameraTarget {
                case .face:
                    statusText = "建立用户档案中……"
                    profileAnalysisProgress = 0
                    await animateProfileProgress(to: 0.78, duration: 0.65)
                    try await Task.sleep(for: .milliseconds(650))
                    steps = completeThreeStepSet(from: try await service.completeFaceScan(input: input))
                    session.markFaceScanned(imagePath: steps.first(where: { $0.stepKey == .userProfile })?.previewPath ?? "")
                    await animateProfileProgress(to: 1, duration: 0.42)
                    statusText = "用户档案已创建完成"
                    try await Task.sleep(for: .milliseconds(320))
                    if session.hasCompletedOnboardingCosmeticsStep {
                        steps = completeThreeStepSet(from: try service.resumeExistingInputs(
                            faceImagePath: session.scannedFaceImagePath,
                            hasCosmetics: true
                        ))
                        preparationProgress = 1
                    } else {
                        preparationProgress = 0.5
                    }
                case .cosmetics:
                    statusText = "扫描化妆品，建立化妆品库中……"
                    await animateProgress(to: 0.72, duration: 0.55)
                    pendingProduct = try await service.recognizeCosmetics(input: input)
                    preparationProgress = max(preparationProgress, 0.72)
                    statusText = "已识别化妆品，请确认添加"
                }
                updateStatusText()
        } catch {
                preparationProgress = session.hasCompletedOnboardingCosmeticsStep
                    ? 1
                    : (session.hasScannedFace ? 0.5 : 0)

                if let failure = error as? VisionRequestFailure {
                    recognitionErrorTitle = cameraTarget == .face
                        ? "用户档案创建失败"
                        : "未识别到化妆品"
                    recognitionErrorMessage = visionFailureMessage(
                        failure,
                        fallbackStage: .processingResult
                    )
                    statusText = failure.visionError.localizedDescription
                    if cameraTarget == .face { profileAnalysisProgress = 0 }
                } else if let visionError = error as? VisionAPIError {
                    recognitionErrorTitle = cameraTarget == .face
                        ? "用户档案创建失败"
                        : "未识别到化妆品"
                    recognitionErrorMessage = visionFailureMessage(
                        visionError,
                        fallbackStage: .processingResult
                    )
                    statusText = visionError.localizedDescription
                    if cameraTarget == .face { profileAnalysisProgress = 0 }
                } else if cameraTarget == .cosmetics,
                   error is CosmeticsRecognitionError {
                    recognitionErrorTitle = "未识别到化妆品"
                    recognitionErrorMessage = error.localizedDescription
                    statusText = "未识别到化妆品，请重新扫描"
                } else if cameraTarget == .cosmetics {
                    recognitionErrorTitle = "保存化妆品失败"
                    recognitionErrorMessage = "化妆品已经识别，但保存失败：\(error.localizedDescription)"
                    statusText = "化妆品保存失败，请重试"
                } else {
                    profileAnalysisProgress = 0
                    recognitionErrorTitle = "用户档案创建失败"
                    recognitionErrorMessage = visionFailureMessage(
                        error,
                        fallbackStage: .processingResult
                    )
                    statusText = error.localizedDescription
                }
        }
    }

    func reportInputError(_ error: VisionAPIError) {
        recognitionErrorTitle = cameraTarget == .face ? "用户档案创建失败" : "未识别到化妆品"
        recognitionErrorMessage = visionFailureMessage(error, fallbackStage: .preparingImage)
        processingStage = .none
        isProcessing = false
    }

    func clearRecognitionError() {
        recognitionErrorMessage = nil
        recognitionErrorTitle = "未识别到化妆品"
    }

    func confirmPendingProduct() {
        guard let product = pendingProduct else { return }
        pendingProduct = nil
        isProcessing = true
        processingStage = .cosmetics
        statusText = "扫描化妆品，建立化妆品库中……"

        Task {
            defer {
                isProcessing = false
                processingStage = .none
            }
            do {
                steps = completeThreeStepSet(from: try service.completeCosmeticsScan(result: product))
                session.reportCosmeticAdded(category: product.category)
                session.markOnboardingCosmeticsStepCompleted()
                let categoryProgress = Double(session.onboardingCosmeticCategories.count) / 3
                await animateProgress(
                    to: session.hasAllRequiredOnboardingCosmetics
                        ? 1
                        : 0.5 + (0.48 * categoryProgress),
                    duration: 0.65
                )
                updateStatusText()
                pendingNavigation = .onboardingCabinet
            } catch {
                pendingProduct = product
                statusText = "添加失败，请重试"
            }
        }
    }

    func rejectPendingProduct() {
        pendingProduct = nil
        statusText = "未添加商品，请重新扫描"
    }

    func tapStep(_ step: OnboardingStep) {
        guard step.isActive, !step.isCompleted else { return }

        switch step.stepKey {
        case .userProfile, .cosmetics:
            cameraTarget = step.stepKey == .userProfile ? .face : .cosmetics
            return // View 负责弹出相机
        case .makeupGenerate:
            generateMakeup()
        }
    }

    func cameraTargetForStep(_ step: OnboardingStep) -> OnboardingCameraTarget? {
        guard step.isActive, !step.isCompleted else { return nil }
        switch step.stepKey {
        case .userProfile: return .face
        case .cosmetics: return .cosmetics
        case .makeupGenerate: return nil
        }
    }

    func generateMakeup() {
        guard !isProcessing, preparationProgress >= 1 else { return }
        isProcessing = true
        processingStage = .makeup
        statusText = "正在生成专属妆容方案……"

        Task { @MainActor in
            defer {
                isProcessing = false
                processingStage = .none
            }
            do {
                steps = completeThreeStepSet(from: try await service.generateMakeup())
                session.markMakeupGenerated()
                updateStatusText()
                checkAllStepsCompleted()
            } catch {
                statusText = "生成失败，请重试"
            }
        }
    }

    func clearNavigation() {
        pendingNavigation = .none
    }

    func canTap(_ step: OnboardingStep) -> Bool {
        guard step.isActive, !step.isCompleted, !isProcessing else { return false }
        if step.stepKey == .makeupGenerate {
            return preparationProgress >= 1
        }
        return true
    }

    private func checkAllStepsCompleted() {
        guard steps.allSatisfy(\.isCompleted) else { return }
        pendingNavigation = .makeupPreview
    }

    private func syncSessionFromSteps() {
        if let profile = steps.first(where: { $0.stepKey == .userProfile }), profile.isCompleted {
            session.markFaceScanned(imagePath: profile.previewPath ?? "")
        }
        if let cosmetics = steps.first(where: { $0.stepKey == .cosmetics }), cosmetics.isCompleted {
            session.markOnboardingCosmeticsStepCompleted()
        }
    }

    private func updateStatusText() {
        if let active = steps.first(where: { $0.isActive && !$0.isCompleted }) {
            switch active.stepKey {
            case .userProfile:
                statusText = "建立用户档案中……"
            case .cosmetics:
                statusText = "识别化妆品中……"
            case .makeupGenerate:
                statusText = preparationProgress >= 1
                    ? "资料准备完成，可以开始生成"
                    : "正在整理用户档案与化妆品库……"
            }
            return
        }

        if steps.allSatisfy(\.isCompleted) {
            statusText = "全部完成，可以开始上妆啦！"
        } else if let lastDone = steps.last(where: \.isCompleted) {
            statusText = "\(lastDone.title)已完成"
        }
    }

    private func animateProgress(to target: Double, duration: Double) async {
        let start = preparationProgress
        let frameCount = 18
        for frame in 1...frameCount {
            guard !Task.isCancelled else { return }
            let fraction = Double(frame) / Double(frameCount)
            preparationProgress = start + (target - start) * fraction
            try? await Task.sleep(for: .seconds(duration / Double(frameCount)))
        }
    }

    private func animateProfileProgress(to target: Double, duration: Double) async {
        let start = profileAnalysisProgress
        let frameCount = 24
        for frame in 1...frameCount {
            guard !Task.isCancelled else { return }
            let fraction = Double(frame) / Double(frameCount)
            profileAnalysisProgress = start + (target - start) * fraction
            try? await Task.sleep(for: .seconds(duration / Double(frameCount)))
        }
    }
}
