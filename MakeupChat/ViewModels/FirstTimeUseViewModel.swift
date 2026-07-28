import Foundation
import Observation
import UIKit

enum OnboardingCameraTarget {
    case face
    case cosmetics
}

enum PendingNavigation: Equatable {
    case none
    case makeupPreview
}

@Observable
@MainActor
final class FirstTimeUseViewModel {
    private(set) var steps: [OnboardingStep] = []
    private(set) var statusText = "扫描脸部，建立用户档案中……"
    private(set) var isProcessing = false
    private(set) var hasStartedProgress = false
    private(set) var preparationProgress = 0.0
    private(set) var pendingProduct: CosmeticsRecognitionResult?
    private(set) var pendingNavigation: PendingNavigation = .none

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
            steps = loaded
            if session.hasScannedFace || session.hasAddedCosmetics {
                steps = try service.resumeExistingInputs(
                    faceImagePath: session.scannedFaceImagePath,
                    hasCosmetics: session.hasAddedCosmetics
                )
                if session.hasScannedFace {
                    hasStartedProgress = true
                    preparationProgress = session.hasAddedCosmetics ? 1 : 0.5
                }
            }
            syncSessionFromSteps()
            updateStatusText()
        } catch {
            steps = []
        }
    }

    func handleCameraCapture(_ image: UIImage) {
        isProcessing = true
        hasStartedProgress = true
        preparationProgress = max(preparationProgress, 0.08)
        Task {
            defer { isProcessing = false }
            do {
                switch cameraTarget {
                case .face:
                    statusText = "扫描脸部，建立用户档案中……"
                    try await Task.sleep(for: .milliseconds(650))
                    steps = try await service.completeFaceScan(image: image)
                    session.markFaceScanned(imagePath: steps.first(where: { $0.stepKey == .userProfile })?.previewPath ?? "")
                    if session.hasAddedCosmetics {
                        steps = try service.resumeExistingInputs(
                            faceImagePath: session.scannedFaceImagePath,
                            hasCosmetics: true
                        )
                        preparationProgress = 1
                    } else {
                        preparationProgress = 0.5
                    }
                case .cosmetics:
                    statusText = "正在识别化妆品信息……"
                    pendingProduct = try await service.recognizeCosmetics(image: image)
                    preparationProgress = max(preparationProgress, 0.72)
                }
                updateStatusText()
            } catch {
                statusText = "保存失败，请重试"
            }
        }
    }

    func confirmPendingProduct() {
        guard let product = pendingProduct else { return }
        pendingProduct = nil
        isProcessing = true
        statusText = "添加到陈列柜，正在完善生成资料……"

        Task {
            defer { isProcessing = false }
            do {
                steps = try service.completeCosmeticsScan(result: product)
                session.markCosmeticsAdded()
                preparationProgress = 0.86
                try await Task.sleep(for: .milliseconds(700))
                preparationProgress = 1
                updateStatusText()
            } catch {
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
        statusText = "正在生成专属妆容方案……"

        Task { @MainActor in
            defer { isProcessing = false }
            do {
                steps = try await service.generateMakeup()
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
}
