import Foundation

/// 全局界面路由 — 首页栈与「我的」栈共用
enum AppRoute: Hashable {
    case aiChat
    case firstTimeUse
    case onboardingCabinet
    case makeupPreview
    case makeupSteps
    case makeupComplete
    case userProfile
}

enum AppTab: Int {
    case home = 0
    case cabinet = 1
    case profile = 2
}
