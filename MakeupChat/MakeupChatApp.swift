import SwiftUI
import TipKit

@main
struct MakeupChatApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // 产品规则为每次重启都重新开始，因此 TipKit 指引也从第一项重置。
                    try? Tips.resetDatastore()
                    try? Tips.configure([
                        .displayFrequency(.immediate)
                    ])
                    // 数据库初始化放到后台，避免启动时卡住白屏
                    await Task.detached(priority: .userInitiated) {
                        _ = DatabaseManager.shared
                    }.value
                }
        }
    }
}
