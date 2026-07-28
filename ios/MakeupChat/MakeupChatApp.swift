import SwiftUI

@main
struct MakeupChatApp: App {
    init() {
        _ = DatabaseManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
