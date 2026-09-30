import Foundation

/// 全局界面路由 — 首页栈与「我的」栈共用
enum AppRoute: Hashable {
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
    /// 左侧独立入口，选中时直接呈现负一屏。
    case ai = 3
}
