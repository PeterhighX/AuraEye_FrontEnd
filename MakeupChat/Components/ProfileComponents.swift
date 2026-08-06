import SwiftUI

struct MakeupHistoryCard: View {
    let item: MakeupHistoryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(item.imageAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .scaleEffect(1.1)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color.black.opacity(0.08), radius: 2)

                VStack(spacing: 10) {
                    ForEach(item.swatchColors, id: \.self) { color in
                        Circle()
                            .fill(color)
                            .frame(width: 20, height: 20)
                    }
                }
                .frame(height: 102)
            }

            Text("\(item.makeupCount)上妆")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(Color(red: 0.15, green: 0.15, blue: 0.15).opacity(0.75))

            Text(item.makeupTime)
            .font(.system(size: 10, weight: .light))
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: 184)
        .background(Color.white.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.09), radius: 2, y: 2)
    }

}

struct ProfileQuickAction: View {
    let title: String
    let systemImage: String
    var iconWidth: CGFloat = 24
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .regular))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.2))
                    .frame(width: iconWidth, height: 24)

                Text(title)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.2))
                    .lineLimit(1)
                    .frame(height: 14)
            }
            .frame(width: 72)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

struct CreditsBadge: View {
    let credits: Int

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.ColorToken.accentOrange)
            Text("\(credits)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(red: 0.15, green: 0.15, blue: 0.15).opacity(0.75))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(red: 0.15, green: 0.15, blue: 0.15).opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct ProfileSectionHeader: View {
    let title: String

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(AppTheme.ColorToken.accentOrange)
                    .frame(width: 6, height: 22)
                Text(title)
                    .font(.system(size: 20, weight: .regular, design: .rounded))
                    .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.2))
            }
            Spacer()
            Image(systemName: "chevron.right.2")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.2))
        }
        .padding(.horizontal, 16)
    }
}
