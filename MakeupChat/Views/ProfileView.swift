import SwiftUI
import UIKit

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

                MyTasksSheet(tasks: session.business.growth?.tasks ?? []) {
                    showMyTasks = false
                }
                .frame(height: 500)
                .offset(y: 34)
                .ignoresSafeArea(.container, edges: .bottom)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(showMyTasks ? .hidden : .visible, for: .tabBar)
        .animation(AppTheme.Motion.stepSpring, value: showMyTasks)
        .onAppear { viewModel.reload() }
        .task {
            await session.business.refreshGrowth()
            await session.business.refreshHistory()
            await session.business.refreshStats()
        }
    }

    private var profileScrollContent: some View {
        VStack(spacing: 0) {
            profileTopRow
                .padding(.top, 8)

            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 16) {
                        levelRow
                        KnowledgeTipBar(surface: "profile")
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
                Text(session.business.growth.map { "LV. \($0.level) · \($0.totalXP) XP" } ?? "等级待同步")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(Color(red: 0.15, green: 0.15, blue: 0.15).opacity(0.75))

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(red: 0.93, green: 0.93, blue: 0.93).opacity(0.75))
                        .frame(height: 8)
                    Capsule()
                        .fill(AppTheme.ColorToken.accentOrange.opacity(0.75))
                        .frame(width: 199 * CGFloat(min(max(session.business.growth?.levelProgress ?? 0, 0), 1)), height: 8)
                }
                .frame(width: 199)
            }

            Spacer()

            if let points = session.business.growth?.wallet.availablePoints {
                CreditsBadge(credits: points)
            } else {
                Text("积分待同步")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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
                utilityCard(
                    title: "上妆统计",
                    subtitle: session.business.makeupStats.map { "累计完成 \($0.completedCount) 次" } ?? "统计待同步",
                    icon: "calendar"
                )
                utilityCard(title: "更多妆容", subtitle: "获取社区内容", icon: "bubble.left.and.bubble.right")
            }
            .padding(.horizontal, 16)
        }
    }

    private var manageProfileCard: some View {
        Button {
            if let profileRoute = session.routeForUserProfile() {
                path.append(profileRoute)
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
                        if let data = session.business.avatarData,
                           let image = UIImage(data: data) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .scaledToFill()
                                .foregroundStyle(.secondary)
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

            if let error = session.business.historyError {
                Text("上妆记录暂不可用：\(error)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
            } else if session.business.makeupHistory.isEmpty {
                Text("暂无上妆记录")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(session.business.makeupHistory) { item in
                            MakeupHistoryCard(item: item)
                        }
                    }
                    .padding(.horizontal, 16)
                }
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
