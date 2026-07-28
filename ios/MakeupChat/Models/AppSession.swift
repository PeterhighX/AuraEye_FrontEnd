import Foundation
import Observation

enum MakeupFlowRoute: Hashable {
    case firstTimeUse
    case makeupPreview
}

@Observable
final class AppSession {
    /// 是否已完成过至少一次上妆流程（非第一次化妆）
    var hasCompletedFirstMakeup: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.hasCompletedFirstMakeup) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.hasCompletedFirstMakeup) }
    }

    /// 是否已在第一次使用流程中完成脸部扫描
    var hasScannedFace: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.hasScannedFace) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.hasScannedFace) }
    }

    var scannedFaceImagePath: String? {
        get { UserDefaults.standard.string(forKey: Keys.scannedFaceImagePath) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.scannedFaceImagePath) }
    }

    var isFirstMakeup: Bool { !hasCompletedFirstMakeup }

    func routeForQuickStart() -> MakeupFlowRoute {
        isFirstMakeup ? .firstTimeUse : .makeupPreview
    }

    func markFaceScanned(imagePath: String) {
        hasScannedFace = true
        scannedFaceImagePath = imagePath
    }

    private enum Keys {
        static let hasCompletedFirstMakeup = "hasCompletedFirstMakeup"
        static let hasScannedFace = "hasScannedFace"
        static let scannedFaceImagePath = "scannedFaceImagePath"
    }
}
