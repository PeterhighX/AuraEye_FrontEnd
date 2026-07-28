import SwiftUI

struct OnboardingStepRow: View {
    let stepNumber: Int
    let title: String
    let subtitle: String
    let buttonTitle: String
    let systemImage: String
    let isActive: Bool
    let isCompleted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.95, green: 0.95, blue: 0.95).opacity(0.25))
                    .frame(width: 76, height: 99)
                    .offset(y: -6)

                Image(systemName: systemImage)
                    .font(.system(size: 28))
                    .foregroundStyle(Color(red: 0.15, green: 0.15, blue: 0.15).opacity(0.55))
            }
            .padding(.leading, 16)

            VStack(alignment: .trailing, spacing: 10) {
                Text(title)
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(Color(red: 0.15, green: 0.15, blue: 0.15).opacity(0.75))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(subtitle)
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(Color(red: 0.15, green: 0.15, blue: 0.15).opacity(0.75))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(indicatorColor)
                        .frame(width: 9, height: 24)

                    Text("Step \(stepNumber)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(red: 0.15, green: 0.15, blue: 0.15).opacity(0.75))
                        .tracking(1)

                    Spacer()

                    Button(action: action) {
                        Text(buttonTitle)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .tracking(1)
                            .frame(width: 90, height: 28)
                            .background(buttonBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .disabled(!isActive)
                }
            }
            .padding(.trailing, 16)
            .padding(.vertical, 16)
        }
        .frame(height: 109)
        .background(Color.white.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.09), radius: 2, y: 2)
        .padding(.horizontal, 16)
    }

    private var indicatorColor: Color {
        if isCompleted { return Color(red: 0.4, green: 0.8, blue: 0.4) }
        if isActive { return Color(red: 1.0, green: 0.88, blue: 0.85) }
        return Color(red: 0.85, green: 0.85, blue: 0.85)
    }

    private var buttonBackground: Color {
        if isCompleted { return Color(red: 0.4, green: 0.8, blue: 0.4) }
        if isActive { return Color(red: 0.15, green: 0.15, blue: 0.15) }
        return Color(red: 0.15, green: 0.15, blue: 0.15).opacity(0.55)
    }
}
