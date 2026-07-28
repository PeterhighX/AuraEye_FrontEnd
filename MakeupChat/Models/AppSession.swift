import Foundation
import Observation

@Observable
final class AppSession {
    /// 当前产品演示规则：每次重新启动 App 都视为第一次使用。
    /// 状态只在本次运行期间保留，不写入 UserDefaults。
    var hasCompletedFirstMakeup = false
    var hasScannedFace = false
    var hasAddedCosmetics = false
    var hasGeneratedMakeup = false
    var scannedFaceImagePath: String?
    var hasResetOnboardingThisLaunch = false
    var shouldRequestProfileCapture = false

    var isFirstMakeup: Bool { !hasCompletedFirstMakeup }

    func routeForQuickStart() -> AppRoute {
        isFirstMakeup ? .firstTimeUse : .makeupPreview
    }

    func markFaceScanned(imagePath: String) {
        hasScannedFace = true
        scannedFaceImagePath = imagePath
    }

    func markCosmeticsAdded() {
        hasAddedCosmetics = true
    }

    func markMakeupGenerated() {
        hasGeneratedMakeup = true
    }

    func requestProfileCapture() {
        shouldRequestProfileCapture = true
    }

    func consumeProfileCaptureRequest() {
        shouldRequestProfileCapture = false
    }
}
