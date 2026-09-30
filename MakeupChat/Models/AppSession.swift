import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class AppSession {
    private(set) var authenticatedAccount: AuthenticatedAccount?
    var hasCompletedFirstMakeup = false
    var hasScannedFace = false
    var hasAddedCosmetics = false
    var hasCompletedOnboardingCosmeticsStep = false
    var hasGeneratedMakeup = false
    var scannedFaceImagePath: String?
    var makeupRenderPreviewPath: String?
    var shouldRequestProfileCapture = false
    /// 负一屏以首页同层覆盖方式呈现时，暂停根 Tab 的横向切换手势。
    var isAIChatPresented = false
    var selectedLookID = "clear_sweet"
    var makeupHistory: [MakeupHistoryItem] = []
    var pendingCosmeticSuccessMessage: String?
    var onboardingCosmeticCategories: Set<CosmeticCategory> = []

    var isFirstMakeup: Bool { !hasCompletedFirstMakeup }
    var isAuthenticated: Bool { authenticatedAccount != nil }
    var hasGeneratedUserProfile: Bool { hasScannedFace }
    var hasAllRequiredOnboardingCosmetics: Bool {
        onboardingCosmeticCategories.isSuperset(of: Set(CosmeticCategory.allCases))
    }

    func routeForQuickStart() -> AppRoute {
        isFirstMakeup ? .firstTimeUse : .makeupPreview
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

    func markMakeupGenerated() {
        hasGeneratedMakeup = true
        hasCompletedFirstMakeup = true
    }

    /// 用户选定妆容并进入后续流程后，本次启动不再重复显示首次引导。
    func markFirstUseCompleted() {
        hasCompletedFirstMakeup = true
    }

    func recordCompletedMakeup() {
        hasCompletedFirstMakeup = true
        let plan = MakeupLookCatalog.plan(id: selectedLookID)
        let item = MakeupHistoryItem(
            title: plan.look.title,
            imageAssetName: plan.look.imageAssetName,
            makeupTime: Date.now.formatted(date: .abbreviated, time: .shortened),
            makeupCount: "第 \(makeupHistory.count + 1) 次",
            swatchColors: plan.look.swatchHexes.map { Color(sessionHex: $0) }
        )
        makeupHistory.insert(item, at: 0)
    }

    func requestProfileCapture() {
        shouldRequestProfileCapture = true
    }

    func completeLogin(with account: AuthenticatedAccount) {
        authenticatedAccount = account
        SessionManager.shared.establish(account: account)

        do {
            let userRepository = UserRepository()
            let cosmeticsRepository = CosmeticsRepository()
            let user = try userRepository.upsertChatUser(
                userId: account.userId,
                displayName: account.displayName
            )
            let cosmetics = try cosmeticsRepository.fetchUserOwned(userId: account.userId)
            restorePersistedProgress(user: user, cosmetics: cosmetics)
        } catch {
            // 登录本身已经成功；本地数据暂不可用时保持空状态，页面仍可正常重试。
            restorePersistedProgress(user: nil, cosmetics: [])
        }
    }

    /// 登录后以本地业务数据为唯一事实来源，恢复快速开始流程。
    /// 不单独持久化布尔值，避免它们与用户档案或陈列柜内容失配。
    func restorePersistedProgress(user: UserProfile?, cosmetics: [CosmeticItem]) {
        let portraitPath = user?.userPortraitPath?.trimmingCharacters(in: .whitespacesAndNewlines)
        let categories = Set(cosmetics.compactMap {
            CosmeticCategory.from(raw: $0.makeupCategory)
        })
        let hasMakeupPreview = user?.eyePreviewPath?.isEmpty == false

        scannedFaceImagePath = portraitPath?.isEmpty == false ? portraitPath : nil
        hasScannedFace = scannedFaceImagePath != nil
        onboardingCosmeticCategories = categories
        hasAddedCosmetics = !categories.isEmpty
        hasCompletedOnboardingCosmeticsStep = hasAllRequiredOnboardingCosmetics
        hasGeneratedMakeup = hasMakeupPreview
        hasCompletedFirstMakeup = hasMakeupPreview
        makeupRenderPreviewPath = nil
        pendingCosmeticSuccessMessage = nil
    }

    func logout() {
        if let userId = authenticatedAccount?.userId {
            ChatSendRegistry.shared.cancel(userId: userId)
        }
        authenticatedAccount = nil
        SessionManager.shared.clear()
        restorePersistedProgress(user: nil, cosmetics: [])
    }

    func consumeProfileCaptureRequest() {
        shouldRequestProfileCapture = false
    }
}

private extension Color {
    init(sessionHex: String) {
        let value = UInt64(sessionHex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
