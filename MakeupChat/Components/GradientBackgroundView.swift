import SwiftUI

/// 全 App 共用的 Metal 动态背景。
///
/// `sharedFluidBackground` 最终沿用输入颜色的 Alpha，因此这里必须提供不透明源色；
/// 如果使用 `Color.clear`，Shader 即使成功执行也会输出全透明画面。
struct AppDynamicBackgroundView: View {
    let isActive: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isActive)) { timeline in
            GeometryReader { proxy in
                Rectangle()
                    .fill(Color.white)
                    .colorEffect(
                        ShaderLibrary.sharedFluidBackground(
                            .float2(proxy.size),
                            .float(timeline.date.timeIntervalSinceReferenceDate),
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

#Preview {
    AppDynamicBackgroundView(isActive: true)
}
