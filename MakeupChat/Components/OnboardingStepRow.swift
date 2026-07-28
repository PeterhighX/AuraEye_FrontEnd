import SwiftUI

struct OnboardingStepRow: View {
    let step: OnboardingStep
    var isActionEnabled = true
    let action: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            StepPreviewThumbnail(step: step)
                .padding(.leading, 16)
                .overlay(alignment: .topTrailing) {
                    if step.isCompleted {
                        Image(systemName: AppTheme.Symbol.checkmark)
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(AppTheme.ColorToken.stepCompleted)
                            .clipShape(Circle())
                            .offset(x: 4, y: -10)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

            VStack(alignment: .trailing, spacing: 10) {
                Text(step.title)
                    .font(AppTheme.Typography.cardTitle)
                    .foregroundStyle(AppTheme.ColorToken.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(step.displaySubtitle)
                    .font(AppTheme.Typography.cardSubtitle)
                    .foregroundStyle(AppTheme.ColorToken.textSecondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(AppTheme.Motion.statusFade, value: step.displaySubtitle)

                HStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(indicatorColor)
                        .frame(width: 9, height: 24)
                        .animation(AppTheme.Motion.stepSpring, value: step.status)

                    Text("Step \(step.stepNumber)")
                        .font(AppTheme.Typography.stepLabel)
                        .foregroundStyle(AppTheme.ColorToken.textSecondary)

                    Spacer()

                    Button(action: action) {
                        Text(step.buttonTitle)
                            .font(AppTheme.Typography.buttonLabel)
                            .foregroundStyle(.white)
                            .frame(width: 90, height: 28)
                            .background(buttonBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(StepButtonStyle())
                    .disabled(!isActionEnabled)
                    .sensoryFeedback(.success, trigger: step.isCompleted)
                }
            }
            .padding(.trailing, 16)
            .padding(.vertical, 16)
        }
        .frame(minHeight: 109)
        .background(AppTheme.ColorToken.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.09), radius: 2, y: 2)
        .padding(.horizontal, 16)
        .animation(AppTheme.Motion.stepSpring, value: step.status)
    }

    private var indicatorColor: Color {
        if step.isCompleted { return AppTheme.ColorToken.stepCompleted }
        if step.isActive { return AppTheme.ColorToken.stepActive }
        return AppTheme.ColorToken.stepPending
    }

    private var buttonBackground: Color {
        if step.isCompleted { return AppTheme.ColorToken.buttonSuccess }
        if step.isActive && isActionEnabled { return AppTheme.ColorToken.buttonPrimary }
        return AppTheme.ColorToken.buttonDisabled
    }
}

/// 按压缩放 — iOS 标准按钮反馈
private struct StepButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(AppTheme.Motion.quickSpring, value: configuration.isPressed)
    }
}
