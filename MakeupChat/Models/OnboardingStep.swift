import Foundation

enum OnboardingStepKey: String, CaseIterable {
    case userProfile = "user_profile"
    case cosmetics = "cosmetics"
    case makeupGenerate = "makeup_generate"

    var stepIndex: Int {
        switch self {
        case .userProfile: return 1
        case .cosmetics: return 2
        case .makeupGenerate: return 3
        }
    }

    var defaultTitle: String {
        switch self {
        case .userProfile: return "用户档案"
        case .cosmetics: return "化妆品"
        case .makeupGenerate: return "妆容生成"
        }
    }

    var defaultSubtitle: String {
        switch self {
        case .userProfile: return "✨ 闪闪正在用火眼金睛分析你的面部特征哦"
        case .cosmetics: return "✨ 闪闪正在认真翻看宝子自己有哪些化妆品……"
        case .makeupGenerate: return "✨ 正在为你规划最不容易手残的保姆级步骤……"
        }
    }

    var completedSubtitle: String {
        switch self {
        case .userProfile: return "✨ 面部扫描完成，闪闪正在整理你的档案"
        case .cosmetics: return "✨ 已识别你的化妆品，陈列柜已更新"
        case .makeupGenerate: return "✨ 专属妆容方案已生成，可以开始上妆啦"
        }
    }

    var defaultButtonTitle: String {
        switch self {
        case .userProfile: return "扫描脸部"
        case .cosmetics: return "扫描化妆品"
        case .makeupGenerate: return "开始生成"
        }
    }

    var completedButtonTitle: String { "已完成" }

    var systemImage: String {
        switch self {
        case .userProfile: return AppTheme.Symbol.userProfile
        case .cosmetics: return AppTheme.Symbol.cosmetics
        case .makeupGenerate: return AppTheme.Symbol.makeupGenerate
        }
    }

    var defaultPreviewAsset: String? {
        switch self {
        case .userProfile: return "PreviewUserProfile"
        case .cosmetics: return "PreviewCosmetics"
        case .makeupGenerate: return "PreviewMakeup"
        }
    }
}

enum OnboardingStepStatus: String {
    case pending
    case inProgress
    case completed

    var isActive: Bool { self == .inProgress }
    var isCompleted: Bool { self == .completed }
}

struct OnboardingStep: Identifiable, Equatable {
    let id: String
    let userId: String
    let stepKey: OnboardingStepKey
    var status: OnboardingStepStatus
    var subtitle: String
    var previewAsset: String?
    var previewPath: String?
    var updatedAt: Date

    var stepNumber: Int { stepKey.stepIndex }
    var title: String { stepKey.defaultTitle }

    var displaySubtitle: String {
        status == .completed ? stepKey.completedSubtitle : subtitle
    }

    var buttonTitle: String {
        switch status {
        case .completed: return stepKey.completedButtonTitle
        case .inProgress: return stepKey.defaultButtonTitle
        case .pending: return stepKey.defaultButtonTitle
        }
    }

    var isActive: Bool {
        status == .inProgress
    }

    var isCompleted: Bool {
        status == .completed
    }

    var systemImage: String { stepKey.systemImage }
}
