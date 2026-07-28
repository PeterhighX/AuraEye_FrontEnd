import SwiftUI

struct MakeupHistoryCard: View {
    let item: MakeupHistoryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.95, green: 0.94, blue: 0.94))
                    .frame(width: 120, height: 120)
                    .overlay {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(Color(red: 0.77, green: 0.65, blue: 0.52).opacity(0.55))
                    }
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

            Text(item.title)
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(Color(red: 0.15, green: 0.15, blue: 0.15).opacity(0.75))

            HStack(spacing: 6) {
                ForEach(item.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 11, weight: .light))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 2)
                        .background(tagBackground(for: tag))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(12)
        .frame(width: 184)
        .background(Color.white.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.09), radius: 2, y: 2)
    }

    private func tagBackground(for tag: String) -> Color {
        tag == item.tags.first
            ? Color(red: 1.0, green: 0.93, blue: 0.91)
            : Color(red: 1.0, green: 0.88, blue: 0.85)
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
