import SwiftUI

struct OnboardingStepRow: View {
    let step: OnboardingStep
    var isActionEnabled = true
    let action: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            StepPreviewThumbnail(step: step)
                .padding(.leading, 16)

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

                HStack(spacing: 27) {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                (isActionEnabled || step.isCompleted)
                                    ? Color(red: 1, green: 225 / 255, blue: 216 / 255)
                                    : Color(red: 217 / 255, green: 217 / 255, blue: 217 / 255)
                            )
                            .frame(width: 9, height: 24)

                        Text("Step \(step.stepNumber)")
                            .font(AppTheme.Typography.stepLabel)
                            .foregroundStyle(AppTheme.ColorToken.textSecondary)
                    }

                    Button(action: action) {
                        Text(step.buttonTitle)
                            .font(AppTheme.Typography.buttonLabel)
                            .foregroundStyle(step.isCompleted ? AppTheme.ColorToken.accentCoral : .white)
                            .frame(width: 90, height: 28)
                            .background(buttonBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(StepButtonStyle())
                    .disabled(!isActionEnabled)
                    .sensoryFeedback(.success, trigger: step.isCompleted)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.trailing, 16)
            .padding(.vertical, 16)
        }
        .frame(minHeight: 131)
        .background(AppTheme.ColorToken.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.09), radius: 2, y: 2)
        .padding(.horizontal, 16)
        .animation(AppTheme.Motion.stepSpring, value: step.status)
    }

    private var buttonBackground: Color {
        if step.isCompleted { return AppTheme.ColorToken.accentCoral.opacity(0.14) }
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
