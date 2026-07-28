import SwiftUI

struct ContentView: View {
    @State private var session = AppSession()
    @State private var homePath = NavigationPath()
    @State private var profilePath = NavigationPath()
    @State private var selectedTab = AppTab.home.rawValue

    var body: some View {
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
    }

    private var homeTab: some View {
        NavigationStack(path: $homePath) {
            HomeView(session: session, path: $homePath, selectedTab: $selectedTab)
                .navigationDestination(for: AppRoute.self) { route in
                    appRouteDestination(route, session: session, path: $homePath)
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GradientBackgroundView())
    }

    private var profileTab: some View {
        NavigationStack(path: $profilePath) {
            ProfileView(session: session, path: $profilePath, selectedTab: $selectedTab)
                .navigationDestination(for: AppRoute.self) { route in
                    appRouteDestination(route, session: session, path: $profilePath)
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}

#Preview {
    ContentView()
}
