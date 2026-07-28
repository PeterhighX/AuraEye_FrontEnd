import SwiftUI

/// Figma 20:1419 — 我的
struct ProfileView: View {
    @Bindable var session: AppSession
    @Binding var path: NavigationPath
    @Binding var selectedTab: Int
    @State private var viewModel = ProfileViewModel()
    @State private var showMyTasks = false

    var body: some View {
        ZStack(alignment: .bottom) {
            profileScrollContent

            if showMyTasks {
                Color.black.opacity(0.66)
                    .ignoresSafeArea()
                    .onTapGesture { showMyTasks = false }
                    .transition(.opacity)

                MyTasksSheet(tasks: viewModel.tasks) {
                    showMyTasks = false
                }
                .frame(height: 463)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .toolbar(.hidden, for: .navigationBar)
        .animation(AppTheme.Motion.stepSpring, value: showMyTasks)
        .onAppear { viewModel.reload() }
    }

    private var profileScrollContent: some View {
        VStack(spacing: 0) {
            profileTopRow
                .padding(.top, 8)

            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 16) {
                        levelRow
                        TipBarView()
                    }
                    mainContent
                    makeupHistorySection
                }
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
        }
    }

    private var profileTopRow: some View {
        UserIdentityHeaderView(user: viewModel.user) {
            Button {} label: {
                Image("ProfileMenu")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("菜单")
        }
    }

    private var levelRow: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text("LV. \(viewModel.level)")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(Color(red: 0.15, green: 0.15, blue: 0.15).opacity(0.75))

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(red: 0.93, green: 0.93, blue: 0.93).opacity(0.75))
                        .frame(height: 8)
                    Capsule()
                        .fill(AppTheme.ColorToken.accentOrange.opacity(0.75))
                        .frame(width: 199 * viewModel.levelProgress, height: 8)
                }
                .frame(width: 199)
            }

            Spacer()

            CreditsBadge(credits: viewModel.user.credits)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Main

    private var mainContent: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                ProfileQuickAction(
                    title: "我的任务",
                    systemImage: "clipboard",
                    iconWidth: 21
                ) {
                    showMyTasks = true
                }

                Spacer(minLength: 0)

                ProfileQuickAction(
                    title: "我的报告",
                    systemImage: "play.rectangle",
                    iconWidth: 24
                ) {}

                Spacer(minLength: 0)

                ProfileQuickAction(
                    title: "我的好友",
                    systemImage: "person.2",
                    iconWidth: 24
                ) {}
            }
            .padding(.horizontal, 24)
            .padding(.horizontal, 16)

            manageProfileCard

            HStack(spacing: 16) {
                utilityCard(title: "上妆周报", subtitle: "05.2~05.11", icon: "calendar")
                utilityCard(title: "更多妆容", subtitle: "获取社区内容", icon: "bubble.left.and.bubble.right")
            }
            .padding(.horizontal, 16)
        }
    }

    private var manageProfileCard: some View {
        Button {
            if session.hasScannedFace {
                path.append(AppRoute.userProfile)
            } else {
                session.requestProfileCapture()
                selectedTab = AppTab.home.rawValue
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.95, green: 0.95, blue: 0.95).opacity(0.25))
                        .frame(width: 62, height: 63)

                    Group {
                        if let portrait = viewModel.user.userPortraitPath {
                            LocalImageView(storedPath: portrait, systemImage: "person.crop.circle.fill")
                                .scaledToFill()
                        } else {
                            Image("AvatarUser")
                                .resizable()
                                .scaledToFill()
                        }
                    }
                    .frame(width: 50, height: 67)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .offset(y: -4)
                }

                Text("管理用户档案")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(Color(red: 0.15, green: 0.15, blue: 0.15).opacity(0.75))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(red: 0.15, green: 0.15, blue: 0.15).opacity(0.5))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    private func utilityCard(title: String, subtitle: String, icon: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.2))
                Text(subtitle)
                    .font(.system(size: 11, weight: .light))
                    .foregroundStyle(Color(red: 0.4, green: 0.4, blue: 0.4))
            }
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(AppTheme.ColorToken.accentOrange)
        }
        .padding(.horizontal, 19)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
    }

    // MARK: - History

    private var makeupHistorySection: some View {
        VStack(spacing: 24) {
            ProfileSectionHeader(title: "上妆记录")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.historyItems) { item in
                        MakeupHistoryCard(item: item)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView(
            session: AppSession(),
            path: .constant(NavigationPath()),
            selectedTab: .constant(2)
        )
    }
}
