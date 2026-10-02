import SwiftUI

enum KnowledgeTipFallbackKind {
    case all
    case profile
    case cosmetics
    case makeup

    var tips: [String] {
        switch self {
        case .all:
            Self.profileTips + Self.cosmeticsTips + Self.makeupTips + Self.generalTips
        case .profile:
            Self.profileTips
        case .cosmetics:
            Self.cosmeticsTips
        case .makeup:
            Self.makeupTips
        }
    }

    private static let profileTips = [
        "闪闪正在用火眼金睛分析你的面部特征哦。",
        "专属的面部大数据正在加马力分析中呢。",
        "闪闪来帮您分析面部情况，宝子等我一下。",
        "正在帮宝子看眼型和脸型，马上就出结果。",
        "闪闪正在精准测量你的五官比例，别走开。"
    ]

    private static let cosmeticsTips = [
        "闪闪搬好小板凳，正等着翻看你的化妆包呢。",
        "快把你手边现有的眼影盘拍给闪闪看看吧。",
        "闪闪正在认真翻看宝子自己有哪些化妆品。",
        "正在扫描你现有的眼影盘，看看能画什么妆。",
        "闪闪在帮你看看手头的化妆品怎么物尽其用。",
        "正在识别宝子的宝贝化妆品，马上帮你搭配。",
        "闪闪正在你的化妆包里为你挑选本命色号。",
        "原来你手头有这么多宝藏，闪闪正在看呢。",
        "正在为你现有的化妆品量身定制专属画法。",
        "闪闪在研究怎么用你现有的刷子画出大眼。"
    ]

    private static let makeupTips = [
        "金牌眼妆教程正在一字一句为你敲出来哦。",
        "闪闪正在把大牌化妆师的独家手法写进教程。",
        "清透消肿的魔幻眼妆步骤马上就要生成啦。",
        "正在为你规划最不容易手残的保姆级步骤。",
        "今日份完美妆容秘籍正在马不停蹄赶来。"
    ]

    private static let generalTips = [
        "美貌魔法正在加载中，宝子再稍微等一下。",
        "专属你的变美秘籍马上就好，赶快期待一下。",
        "闪闪正在为你全力以赴，好妆容值得等待。",
        "美丽值正在疯狂充值中，马上就为你揭晓。",
        "宝子稍微喝口水，闪闪马上把报告双手奉上。"
    ]
}

/// 小知识横条的显示组件；业务页面由 KnowledgeTipBar 获取后端内容。
struct TipBarView: View {
    let text: String

    var body: some View {
        HStack(spacing: 0) {
            Text("小知识")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(.white)
                .tracking(1)
                .frame(width: 64)
                .padding(.vertical, 4)
                .background(Color(red: 0.15, green: 0.15, blue: 0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Text(text)
                .font(.system(size: 12, weight: .thin))
                .foregroundStyle(Color(red: 0.15, green: 0.15, blue: 0.15))
                .tracking(1)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color(red: 0.89, green: 0.88, blue: 0.88).opacity(0.24))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .animation(AppTheme.Motion.statusFade, value: text)
                .id(text)
        }
        .padding(.horizontal, 16)
    }
}

struct KnowledgeTipBar: View {
    let surface: String
    var planID: String?
    var stepID: String?
    var fallbackKind: KnowledgeTipFallbackKind = .all

    @State private var item: KnowledgeTipDTO.Item?
    @State private var reportedID: String?
    @State private var fallbackIndex = 0

    private var requestKey: String { "\(surface):\(planID ?? ""):\(stepID ?? "")" }
    private var fallbackTips: [String] { fallbackKind.tips }
    private var displayedText: String {
        item?.text ?? fallbackTips[fallbackIndex % fallbackTips.count]
    }

    var body: some View {
        TipBarView(text: displayedText)
        .task(id: requestKey) {
            item = nil
            reportedID = nil
            fallbackIndex = 0
            if SessionManager.shared.context != nil {
                item = try? await BusinessDataService.shared.tip(
                    surface: surface, planID: planID, stepID: stepID
                )
            }
            guard item == nil, fallbackTips.count > 1 else { return }
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(5))
                } catch {
                    break
                }
                fallbackIndex = (fallbackIndex + 1) % fallbackTips.count
            }
        }
        .task(id: item?.id) {
            guard let item, reportedID != item.id else { return }
            reportedID = item.id
            try? await BusinessDataService.shared.recordTipEvent(
                item, surface: surface, type: "tip_shown"
            )
        }
    }
}

/// 视觉任务的统一转场层：固定 75pt 矢量标记、低速匀速旋转，并展示知识卡片。
struct OperationTransitionOverlay: View {
    let message: String
    let surface: String
    var fallbackKind: KnowledgeTipFallbackKind = .all

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animationStartedAt = Date.now

    private let rotationDuration: TimeInterval = 3.2

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .opacity(0.97)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                TimelineView(.animation(minimumInterval: 1 / 60, paused: reduceMotion)) { context in
                    Image("TransitionSpinner")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 75, height: 75)
                        .rotationEffect(.degrees(rotationAngle(at: context.date)))
                        .accessibilityHidden(true)
                }

                KnowledgeTipBar(surface: surface, fallbackKind: fallbackKind)
                    .frame(maxWidth: 390)

                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            animationStartedAt = .now
        }
        .transition(.opacity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }

    private func rotationAngle(at date: Date) -> Double {
        guard !reduceMotion else { return 0 }
        let elapsed = max(0, date.timeIntervalSince(animationStartedAt))
        return elapsed.truncatingRemainder(dividingBy: rotationDuration) / rotationDuration * 360
    }
}

#Preview {
    TipBarView(text: "轻握刷尾可帮助控制晕染力度。")
}
