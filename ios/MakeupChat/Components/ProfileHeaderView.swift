import SwiftUI

struct ProfileHeaderView: View {
    let user: UserProfile

    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                Image("AvatarUser")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .padding(.leading, 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName)
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.2))

                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                        Text(user.status)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.2))
                    }
                }
                .padding(.leading, 12)

                Spacer()

                HStack(spacing: 8) {
                    HStack(spacing: 9) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.yellow)
                        Text("\(user.credits)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.25))
                    .clipShape(Capsule())

                    iconButton(systemName: "line.3.horizontal")
                    iconButton(systemName: "chevron.right")
                }
                .padding(.trailing, 16)
            }
        }
        .frame(height: 44)
    }

    private func iconButton(systemName: String) -> some View {
        Button {} label: {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.2))
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.35))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
