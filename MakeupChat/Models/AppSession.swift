import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class AppSession {
    private(set) var authenticatedAccount: AuthenticatedAccount?
    let business = BusinessStore.shared
    private(set) var demoRun: DemoRunDTO?
    private(set) var demoRunError: String?
    private(set) var isOpeningDemoRun = false
    private var demoOpenRequestID: String?
    var hasScannedFace = false
    var hasAddedCosmetics = false
    var hasCompletedOnboardingCosmeticsStep = false
    var scannedFaceImagePath: String?
    var shouldRequestProfileCapture = false
    /// 负一屏以首页同层覆盖方式呈现时，暂停根 Tab 的横向切换手势。
    var isAIChatPresented = false
    var selectedLookID = ""
    var pendingCosmeticSuccessMessage: String?
    var onboardingCosmeticCategories: Set<CosmeticCategory> = []

    var isAuthenticated: Bool { authenticatedAccount != nil }
    var isDemoAccount: Bool { authenticatedAccount?.accountMode == .demo }
    var hasGeneratedUserProfile: Bool { business.visualProfile != nil }
    var hasAllRequiredOnboardingCosmetics: Bool {
        onboardingCosmeticCategories.isSuperset(of: Set(CosmeticCategory.allCases))
    }

    func routeForQuickStart() -> AppRoute? {
        if isDemoAccount {
            guard demoRunError == nil, let demoRun else { return nil }
            if let sessionID = demoRun.activeSessionID {
                guard business.activeSession?.sessionID == sessionID,
                      business.activePlan?.planID == demoRun.activePlanID else { return nil }
                return .makeupSteps
            }
            switch demoRun.nextStep {
            case "face_analysis", "eyeshadow_recognition", "eyeliner_recognition", "brush_recognition":
                return .firstTimeUse
            case "makeup_plan", "makeup_practice", nil:
                return .makeupPreview
            default:
                return nil
            }
        }
        if business.completion == nil,
           business.activePlan != nil,
           business.activeSession?.status == "in_progress" {
            return .makeupSteps
        }
        guard let growth = business.growth else { return nil }
        return growth.completedMakeupCount == 0 ? .firstTimeUse : .makeupPreview
    }

    /// 首页与「我的」共用同一档案入口判断。
    /// 返回 nil 代表本次启动尚未建档，需要先拍照或从相册选择。
    func routeForUserProfile() -> AppRoute? {
        hasGeneratedUserProfile ? .userProfile : nil
    }

    func markFaceScanned(imagePath: String) {
        hasScannedFace = true
        scannedFaceImagePath = imagePath
    }

    func markCosmeticsAdded() {
        hasAddedCosmetics = true
    }

    func markOnboardingCosmeticsStepCompleted() {
        guard hasAllRequiredOnboardingCosmetics else { return }
        hasAddedCosmetics = true
        hasCompletedOnboardingCosmeticsStep = true
    }

    func reportCosmeticAdded(category: String) {
        if let normalized = CosmeticCategory.from(raw: category) {
            onboardingCosmeticCategories.insert(normalized)
        }
        hasAddedCosmetics = !onboardingCosmeticCategories.isEmpty
        hasCompletedOnboardingCosmeticsStep = hasAllRequiredOnboardingCosmetics
        pendingCosmeticSuccessMessage = "\(category)已添加成功"
    }

    func consumeCosmeticSuccessMessage() -> String? {
        defer { pendingCosmeticSuccessMessage = nil }
        return pendingCosmeticSuccessMessage
    }

    /// 切换推荐风格只更改选择；旧计划仍保持自己的不可变来源。
    func selectLook(id: String) {
        selectedLookID = id
    }

    func syncProfileAvailability() {
        hasScannedFace = business.visualProfile != nil
    }

    func requestProfileCapture() {
        shouldRequestProfileCapture = true
    }

    func completeLogin(with account: AuthenticatedAccount) {
        authenticatedAccount = account
        SessionManager.shared.establish(account: account)
        business.reset(for: account.userId)
        demoRun = nil
        demoRunError = nil
        isOpeningDemoRun = account.accountMode == .demo
        demoOpenRequestID = nil
        selectedLookID = ""
        shouldRequestProfileCapture = false
        Task {
            if account.accountMode == .demo { await openDemoRun() }
            await business.refreshGrowth()
            await business.checkInToday()
            await business.refreshProfile()
            if business.profileError == nil {
                hasScannedFace = business.visualProfile != nil
            }
            await business.refreshStyles()
            await business.refreshCosmetics()
            if business.cosmeticsError == nil { syncCosmeticCategoriesFromServer() }
            await business.refreshHistory()
            if account.accountMode == .standard { await business.restoreActivePractice() }
        }

        do {
            let userRepository = UserRepository()
            let user = try userRepository.upsertChatUser(
                userId: account.userId,
                displayName: account.displayName
            )
            restorePersistedProgress(user: user)
        } catch {
            // 登录本身已经成功；本地数据暂不可用时保持空状态，页面仍可正常重试。
            restorePersistedProgress(user: nil)
        }
    }

    func openDemoRun() async {
        guard let account = authenticatedAccount, account.accountMode == .demo else { return }
        isOpeningDemoRun = true
        do {
            let buildID = try DemoBuildID.load()
            let requestID = demoOpenRequestID ?? UUID().uuidString
            demoOpenRequestID = requestID
            let opened = try await BusinessDataService.shared.openDemoRun(
                buildID: buildID, requestID: requestID
            )
            guard authenticatedAccount?.userId == account.userId else { return }
            if demoRun?.runID != opened.runID { business.clearActiveFlow() }
            demoRun = opened
            demoRunError = nil
            demoOpenRequestID = nil
            SessionManager.shared.installDemoRun(opened, for: account.userId)
            await business.restoreDemoPractice(run: opened)
        } catch {
            guard authenticatedAccount?.userId == account.userId else { return }
            demoRun = nil
            demoRunError = error.localizedDescription
            SessionManager.shared.clearDemoRun()
        }
        if authenticatedAccount?.userId == account.userId { isOpeningDemoRun = false }
    }

    func refreshDemoRun() async {
        guard let account = authenticatedAccount, account.accountMode == .demo else { return }
        guard let current = demoRun else { await openDemoRun(); return }
        do {
            let refreshed = try await BusinessDataService.shared.demoRun(id: current.runID)
            guard authenticatedAccount?.userId == account.userId,
                  demoRun?.runID == current.runID else { return }
            demoRun = refreshed
            demoRunError = nil
            SessionManager.shared.installDemoRun(refreshed, for: account.userId)
            await business.restoreDemoPractice(run: refreshed)
        } catch {
            guard authenticatedAccount?.userId == account.userId else { return }
            if (error as? APIClientError)?.problemCode == "DEMO_RUN_STALE" {
                demoRun = nil
                SessionManager.shared.clearDemoRun()
                business.clearActiveFlow()
                await openDemoRun()
            } else {
                demoRunError = error.localizedDescription
                SessionManager.shared.clearDemoRun()
            }
        }
    }

    func handleDemoWriteError(_ error: Error) async {
        guard isDemoAccount, DemoRunError.isStale(error) else { return }
        demoRun = nil
        SessionManager.shared.clearDemoRun()
        business.clearActiveFlow()
        await openDemoRun()
    }

    /// 本地只恢复拍摄流程的临时图片；商品类别由服务端列表恢复。
    func restorePersistedProgress(user: UserProfile?) {
        let portraitPath = user?.userPortraitPath?.trimmingCharacters(in: .whitespacesAndNewlines)

        scannedFaceImagePath = portraitPath?.isEmpty == false ? portraitPath : nil
        hasScannedFace = scannedFaceImagePath != nil
        onboardingCosmeticCategories = []
        hasAddedCosmetics = false
        hasCompletedOnboardingCosmeticsStep = false
        pendingCosmeticSuccessMessage = nil
    }

    func syncCosmeticCategoriesFromServer() {
        onboardingCosmeticCategories = Set(business.cosmetics.compactMap {
            CosmeticCategory.from(raw: $0.category)
        })
        hasAddedCosmetics = !onboardingCosmeticCategories.isEmpty
        hasCompletedOnboardingCosmeticsStep = hasAllRequiredOnboardingCosmetics
    }

    func logout() {
        if let userId = authenticatedAccount?.userId {
            ChatSendRegistry.shared.cancel(userId: userId)
        }
        authenticatedAccount = nil
        SessionManager.shared.clear()
        business.reset(for: nil)
        demoRun = nil
        demoRunError = nil
        isOpeningDemoRun = false
        demoOpenRequestID = nil
        restorePersistedProgress(user: nil)
        selectedLookID = ""
        shouldRequestProfileCapture = false
    }

    func consumeProfileCaptureRequest() {
        shouldRequestProfileCapture = false
    }
}
