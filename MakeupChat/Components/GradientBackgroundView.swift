import SwiftUI

/// 全 App 共用的 Metal 动态背景。
///
/// `sharedFluidBackground` 最终沿用输入颜色的 Alpha，因此这里必须提供不透明源色；
/// 如果使用 `Color.clear`，Shader 即使成功执行也会输出全透明画面。
struct AppDynamicBackgroundView: View {
    let isActive: Bool
    private static let animationEpoch = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isActive)) { timeline in
            GeometryReader { proxy in
                let elapsedTime = timeline.date.timeIntervalSince(Self.animationEpoch)

                Rectangle()
                    .fill(Color.white)
                    .colorEffect(
                        ShaderLibrary.sharedFluidBackground(
                            .float2(proxy.size),
                            // Metal 的 `float` 无法保留绝对时间戳里的帧级小数精度。
                            // 使用进程内相对时间，确保每帧传入 shader 的值都真实变化。
                            .float(elapsedTime),
                            .float(isActive ? 1 : 0)
                        )
                    )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension View {
    /// 将 shader 放进当前页面自身的渲染层，避免被 NavigationStack/TabView 的
    /// UIKit 容器默认白色背景挡住。
    func appDynamicBackground(isActive: Bool = true) -> some View {
        ZStack {
            AppDynamicBackgroundView(isActive: isActive)
            self
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    AppDynamicBackgroundView(isActive: true)
}
