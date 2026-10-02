import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var session = AppSession()
    @State private var loginViewModel = LoginViewModel()
    @State private var homePath = NavigationPath()
    @State private var profilePath = NavigationPath()
    @State private var selectedTab = AppTab.home.rawValue

    var body: some View {
        Group {
            if session.isAuthenticated {
                mainApplication
                    .transition(.opacity.combined(with: .scale(scale: 1.015)))
            } else {
                LoginView(viewModel: loginViewModel) { account in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        session.completeLogin(with: account)
                    }
                }
                .transition(.opacity)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, session.isDemoAccount {
                Task { await session.refreshDemoRun() }
            }
        }
    }

    private var mainApplication: some View {
        Group {
            if #available(iOS 27.0, *) {
                separatedAITabView(role: .prominent)
            } else if #available(iOS 18.0, *) {
                separatedAITabView(role: .search)
            } else {
                standardTabView
            }
        }
        .tint(Color(red: 253 / 255, green: 124 / 255, blue: 84 / 255))
        .preferredColorScheme(.light)
        .simultaneousGesture(
            DragGesture(minimumDistance: 30)
                .onEnded(handleTabSwipe)
        )
    }

    @available(iOS 18.0, *)
    private func separatedAITabView(role: TabRole) -> some View {
        TabView(selection: $selectedTab) {
            // Tab 容器使用 RTL 将突出入口放到左侧；普通 Tab 反向声明后，
            // 视觉顺序仍保持「首页 / 陈列柜 / 我的」。页面内容恢复 LTR。
            Tab("我的", systemImage: "person.fill", value: AppTab.profile.rawValue) {
                profileTab
                    .environment(\.layoutDirection, .leftToRight)
            }

            Tab("陈列柜", systemImage: "square.grid.2x2", value: AppTab.cabinet.rawValue) {
                DisplayCabinetView(session: session)
                    .environment(\.layoutDirection, .leftToRight)
            }

            Tab("首页", systemImage: "house.fill", value: AppTab.home.rawValue) {
                homeTab
                    .environment(\.layoutDirection, .leftToRight)
            }

            Tab("AI", image: "HomeAIIcon", value: AppTab.ai.rawValue, role: role) {
                aiTab
                    .environment(\.layoutDirection, .leftToRight)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private var standardTabView: some View {
        TabView(selection: $selectedTab) {
            aiTab
                .tabItem {
                    Label("AI", image: "HomeAIIcon")
                }
                .tag(AppTab.ai.rawValue)

            homeTab
                .tabItem {
                    Label("首页", systemImage: "house.fill")
                }
                .tag(AppTab.home.rawValue)

            DisplayCabinetView(session: session)
                .tabItem {
                    Label("陈列柜", systemImage: "square.grid.2x2")
                }
                .tag(AppTab.cabinet.rawValue)

            profileTab
                .tabItem {
                    Label("我的", systemImage: "person.fill")
                }
                .tag(AppTab.profile.rawValue)
        }
    }

    private var aiTab: some View {
        AIChatTabView(session: session) {
            selectedTab = AppTab.home.rawValue
        }
    }

    private var homeTab: some View {
        NavigationStack(path: $homePath) {
            HomeView(
                session: session,
                path: $homePath,
                selectedTab: $selectedTab
            )
                .navigationDestination(for: AppRoute.self) { route in
                    appRouteDestination(
                        route,
                        session: session,
                        path: $homePath
                    )
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }

    private var profileTab: some View {
        NavigationStack(path: $profilePath) {
            ProfileView(session: session, path: $profilePath, selectedTab: $selectedTab)
                .navigationDestination(for: AppRoute.self) { route in
                    appRouteDestination(
                        route,
                        session: session,
                        path: $profilePath
                    )
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }

    private func handleTabSwipe(_ value: DragGesture.Value) {
        guard canSwipeBetweenMainTabs else { return }
        guard abs(value.translation.width) > abs(value.translation.height) * 1.6 else { return }

        let committedLeft = value.translation.width < -120 &&
            value.predictedEndTranslation.width < -160
        let committedRight = value.translation.width > 120 &&
            value.predictedEndTranslation.width > 160

        withAnimation(.easeInOut(duration: 0.22)) {
            if committedLeft {
                selectedTab = min(selectedTab + 1, AppTab.profile.rawValue)
            } else if committedRight {
                selectedTab = max(selectedTab - 1, AppTab.home.rawValue)
            }
        }
    }

    private var canSwipeBetweenMainTabs: Bool {
        guard !session.isAIChatPresented else { return false }
        switch selectedTab {
        case AppTab.home.rawValue:
            return homePath.isEmpty
        case AppTab.profile.rawValue:
            return profilePath.isEmpty
        default:
            return true
        }
    }

}

#Preview {
    ContentView()
}
