import SwiftUI

@main
struct MakeupChatApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // 数据库初始化放到后台，避免启动时卡住白屏
                    await Task.detached(priority: .userInitiated) {
                        _ = DatabaseManager.shared
                    }.value
                }
        }
    }
}
