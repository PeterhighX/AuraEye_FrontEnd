import SwiftUI

/// 小知识横条 — 从 `TipLibrary` 轮播，默认每 5 秒切换一条
struct TipBarView: View {
    let tips: [String]
    let interval: TimeInterval

    @State private var currentIndex = 0

    init(tips: [String] = TipLibrary.allTips, interval: TimeInterval = 5) {
        self.tips = tips.isEmpty ? TipLibrary.allTips : tips
        self.interval = interval
    }

    private var currentTip: String {
        tips[currentIndex % tips.count]
    }

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

            Text(currentTip)
                .font(.system(size: 12, weight: .thin))
                .foregroundStyle(Color(red: 0.15, green: 0.15, blue: 0.15))
                .tracking(1)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color(red: 0.89, green: 0.88, blue: 0.88).opacity(0.24))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .animation(AppTheme.Motion.statusFade, value: currentIndex)
                .id(currentIndex)
        }
        .padding(.horizontal, 16)
        .task {
            guard tips.count > 1 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                currentIndex = (currentIndex + 1) % tips.count
            }
        }
    }
}

/// 视觉任务的统一转场层：固定 75pt 矢量标记、低速匀速旋转，并展示知识卡片。
struct OperationTransitionOverlay: View {
    let message: String
    let tips: [String]

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

                TipBarView(tips: tips, interval: 4.5)
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
    TipBarView()
}
