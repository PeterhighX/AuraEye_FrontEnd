import SwiftUI

struct MakeupFlowHeaderView: View {
    let title: String
    var onBack: (() -> Void)?

    var body: some View {
        HStack {
            Button {
                onBack?()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color(red: 0.15, green: 0.15, blue: 0.15))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)

            Text(title)
                .font(.system(size: 24, weight: .regular, design: .rounded))
                .foregroundStyle(Color(red: 0.15, green: 0.15, blue: 0.15).opacity(0.8))

            Spacer()

            HStack(spacing: 8) {
                iconCircle(systemName: "sparkles")
                iconCircle(systemName: "line.3.horizontal")
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }

    private func iconCircle(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(Color(red: 0.15, green: 0.15, blue: 0.15))
            .frame(width: 36, height: 36)
            .background(Color.white.opacity(0.35))
            .clipShape(Circle())
    }
}
