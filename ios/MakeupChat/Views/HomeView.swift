import SwiftUI

struct HomeView: View {
    @Bindable var session: AppSession
    @Binding var path: NavigationPath

    @State private var user = UserProfile(
        userId: "mrs_zhang",
        displayName: "Mrs.Zhang",
        status: "开心",
        credits: 50
    )

    private let recommendedLooks = [
        ("清透甜美", "少女感"),
        ("中式温婉", "东方韵味"),
        ("气质港风", "复古范")
    ]

    var body: some View {
        ZStack {
            GradientBackgroundView()

            ScrollView {
                VStack(spacing: 32) {
                    homeHeader
                    growthProgress
                    teachingCard
                    secondaryActions
                    TipBarView(tipText: "毛刷的作用可以柔化边缘，但是要定时清理哦！")
                    recommendedSection
                }
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
        }
        .navigationBarHidden(true)
        .onAppear(perform: loadUser)
    }

    private var homeHeader: some View {
        HStack(spacing: 12) {
            Image("AvatarUser")
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.2))
                HStack(spacing: 4) {
                    Circle().fill(.green).frame(width: 10, height: 10)
                    Text(user.status)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.2))
                }
            }

            Spacer()

            Button {} label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.2))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.35))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }

    private var growthProgress: some View {
        HStack(alignment: .bottom) {
            Image(systemName: "sparkles")
                .font(.system(size: 24))
                .foregroundStyle(.white)
                .frame(width: 70, height: 44)

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                HStack {
                    Text("成长进度")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(.white)
                    Text("LV.04")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color(red: 0.97, green: 0.47, blue: 0.33))
                        .clipShape(Capsule())
                }
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.6)).frame(height: 6)
                    Capsule().fill(Color(red: 1.0, green: 0.55, blue: 0.41)).frame(width: 23, height: 6)
                }
                .frame(width: 165)
            }
        }
        .padding(.horizontal, 16)
    }

    private var teachingCard: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(red: 1.0, green: 0.93, blue: 0.91).opacity(0.4))
                    .shadow(color: Color.black.opacity(0.09), radius: 2, y: 2)
                    .frame(height: 148)

                Image(systemName: "cloud.sun.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.white)
                    .padding(.leading, 18)
                    .padding(.top, -8)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("上妆教学")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color(red: 0.15, green: 0.15, blue: 0.15))
                    Text("跟随教程开启你的眼妆之路")
                        .font(.system(size: 14, weight: .thin))
                        .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.2))
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 18)
                .padding(.top, 19)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 2) {
                        Text("26")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(Color(red: 0.33, green: 0.33, blue: 0.33))
                        VStack(alignment: .leading, spacing: 0) {
                            Text("℃").font(.system(size: 10)).foregroundStyle(.gray)
                            Text("多云").font(.system(size: 10)).foregroundStyle(.gray)
                        }
                    }
                    Text("福田区")
                        .font(.system(size: 12, weight: .light))
                        .padding(.horizontal, 6)
                        .background(Color(red: 0.88, green: 0.96, blue: 0.99).opacity(0.45))
                        .clipShape(Capsule())
                }
                .padding(.leading, 18)
                .padding(.top, 78)

                Button {
                    path.append(session.routeForQuickStart())
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "paintbrush.pointed.fill")
                            .font(.system(size: 20))
                        Text("快速开始")
                            .font(.system(size: 16, weight: .semibold))
                            .tracking(1)
                    }
                    .foregroundStyle(.white)
                    .frame(width: 166, height: 48)
                    .background(Color(red: 0.15, green: 0.15, blue: 0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 18)
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 16)

            HStack(spacing: 12) {
                secondaryButton(title: "化妆品识别", color: Color(red: 0.88, green: 0.88, blue: 1.0), icon: "camera.fill")
                secondaryButton(title: "用户档案", color: Color(red: 1.0, green: 0.71, blue: 0.62), icon: "person.fill")
            }
            .padding(.horizontal, 16)
        }
    }

    private func secondaryButton(title: String, color: Color, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
            Text(title)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .tracking(1)
        }
        .foregroundStyle(Color(red: 0.15, green: 0.15, blue: 0.15))
        .frame(maxWidth: .infinity)
        .frame(height: 57)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.09), radius: 2, y: 2)
    }

    private var secondaryActions: some View {
        EmptyView()
    }

    private var recommendedSection: some View {
        VStack(spacing: 24) {
            HStack {
                Text("推荐眼妆")
                    .font(.system(size: 20, weight: .regular, design: .rounded))
                    .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.2))
                Spacer()
                Image(systemName: "chevron.right.2")
                    .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.2))
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(recommendedLooks, id: \.0) { look in
                        VStack(alignment: .leading, spacing: 12) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(red: 0.95, green: 0.94, blue: 0.94))
                                .frame(width: 120, height: 120)
                                .overlay {
                                    Image(systemName: "eye.fill")
                                        .font(.system(size: 32))
                                        .foregroundStyle(Color(red: 0.77, green: 0.65, blue: 0.52).opacity(0.6))
                                }
                            Text(look.0)
                                .font(.system(size: 14, weight: .light))
                            Text(look.1)
                                .font(.system(size: 11, weight: .light))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 2)
                                .background(Color(red: 0.95, green: 0.94, blue: 0.94))
                                .clipShape(Capsule())
                        }
                        .frame(width: 120)
                    }
                }
                .padding(.horizontal, 12)
            }
        }
    }

    private func loadUser() {
        if let loaded = try? UserRepository().currentUser() {
            user = loaded
        }
    }
}

#Preview {
    NavigationStack {
        HomeView(session: AppSession(), path: .constant(NavigationPath()))
    }
}
