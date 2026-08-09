import SwiftUI

struct ContentView: View {
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
    }

    private var mainApplication: some View {
        TabView(selection: $selectedTab) {
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
        .tint(Color(red: 253 / 255, green: 124 / 255, blue: 84 / 255))
        .preferredColorScheme(.light)
        .simultaneousGesture(
            DragGesture(minimumDistance: 30)
                .onEnded(handleTabSwipe)
        )
    }

    private var homeTab: some View {
        NavigationStack(path: $homePath) {
            HomeView(session: session, path: $homePath, selectedTab: $selectedTab)
                .navigationDestination(for: AppRoute.self) { route in
                    appRouteDestination(
                        route,
                        session: session,
                        path: $homePath,
                        selectedTab: $selectedTab
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
                        path: $profilePath,
                        selectedTab: $selectedTab
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
