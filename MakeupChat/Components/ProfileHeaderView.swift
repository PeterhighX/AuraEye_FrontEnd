import SwiftUI

/// 主页面统一用户信息栏。
/// 头像、姓名和心情状态在首页、陈列柜与“我的”页始终使用同一坐标与尺寸。
struct UserIdentityHeaderView<Trailing: View>: View {
    let user: UserProfile
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let portrait = user.userPortraitPath {
                    LocalImageView(
                        storedPath: portrait,
                        systemImage: "person.crop.circle.fill"
                    )
                    .scaledToFill()
                } else {
                    Image("AvatarUser")
                        .resizable()
                        .scaledToFill()
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.2))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)
                    Text(user.status)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.2))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            trailing()
        }
        .frame(height: 44)
        .padding(.horizontal, 16)
    }
}

extension UserIdentityHeaderView where Trailing == EmptyView {
    init(user: UserProfile) {
        self.user = user
        self.trailing = { EmptyView() }
    }
}

struct ProfileHeaderView: View {
    let user: UserProfile

    var body: some View {
        UserIdentityHeaderView(user: user) {
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
        }
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
