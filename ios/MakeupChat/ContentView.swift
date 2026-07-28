import SwiftUI

struct ContentView: View {
    @State private var session = AppSession()
    @State private var homePath = NavigationPath()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $homePath) {
                HomeView(session: session, path: $homePath)
                    .navigationDestination(for: MakeupFlowRoute.self) { route in
                        switch route {
                        case .firstTimeUse:
                            FirstTimeUseView(session: session)
                        case .makeupPreview:
                            MakeupPreviewView()
                        }
                    }
            }
            .tabItem {
                Label("首页", systemImage: "house.fill")
            }
            .tag(0)

            PlaceholderTabView(title: "陈列柜", systemImage: "square.grid.2x2")
                .tabItem {
                    Label("陈列柜", systemImage: "square.grid.2x2")
                }
                .tag(1)

            PlaceholderTabView(title: "我的", systemImage: "person.fill")
                .tabItem {
                    Label("我的", systemImage: "person.fill")
                }
                .tag(2)
        }
        .tint(Color(red: 0.99, green: 0.49, blue: 0.33))
    }
}

#Preview {
    ContentView()
}
