import SwiftUI

/// 小知识横条的显示组件；业务页面由 KnowledgeTipBar 获取后端内容。
struct TipBarView: View {
    let text: String
    var onDismiss: (() -> Void)? = nil

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
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭小知识")
            }
        }
        .padding(.horizontal, 16)
    }
}

struct KnowledgeTipBar: View {
    let surface: String
    var planID: String?
    var stepID: String?

    @State private var item: KnowledgeTipDTO.Item?
    @State private var reportedID: String?
    @State private var dismissedID: String?

    private var requestKey: String { "\(surface):\(planID ?? ""):\(stepID ?? "")" }

    var body: some View {
        Group {
            if let item, dismissedID != item.id {
                TipBarView(text: item.text) {
                    dismissedID = item.id
                    Task {
                        try? await BusinessDataService.shared.recordTipEvent(
                            item, surface: surface, type: "tip_dismissed"
                        )
                    }
                }
                    .onAppear {
                        guard reportedID != item.id else { return }
                        reportedID = item.id
                        Task {
                            try? await BusinessDataService.shared.recordTipEvent(
                                item, surface: surface, type: "tip_shown"
                            )
                        }
                    }
            }
        }
        .task(id: requestKey) {
            item = nil
            reportedID = nil
            dismissedID = nil
            guard SessionManager.shared.context != nil else { return }
            item = try? await BusinessDataService.shared.tip(
                surface: surface, planID: planID, stepID: stepID
            )
        }
    }
}

/// 视觉任务的统一转场层：固定 75pt 矢量标记、低速匀速旋转，并展示知识卡片。
struct OperationTransitionOverlay: View {
    let message: String
    let surface: String

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

                KnowledgeTipBar(surface: surface)
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
