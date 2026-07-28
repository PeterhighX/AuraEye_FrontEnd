import Foundation
import SwiftUI

struct MakeupHistoryItem: Identifiable {
    let id = UUID()
    let title: String
    let tags: [String]
    let swatchColors: [Color]
}

struct UserTaskItem: Identifiable {
    let id = UUID()
    let title: String
    let reward: Int
    let isCompleted: Bool
}

extension ProfileViewModel {
    static let defaultHistory: [MakeupHistoryItem] = [
        MakeupHistoryItem(
            title: "清透甜美",
            tags: ["少女感", "温柔"],
            swatchColors: [
                Color(red: 0.91, green: 0.78, blue: 0.70),
                Color(red: 0.85, green: 0.72, blue: 0.65),
                Color(red: 0.77, green: 0.65, blue: 0.52)
            ]
        ),
        MakeupHistoryItem(
            title: "中式温婉",
            tags: ["东方韵", "雅致", "气质"],
            swatchColors: [
                Color(red: 0.82, green: 0.68, blue: 0.58),
                Color(red: 0.74, green: 0.58, blue: 0.50),
                Color(red: 0.66, green: 0.50, blue: 0.44)
            ]
        ),
        MakeupHistoryItem(
            title: "气质港风",
            tags: ["复古范", "优雅", "韵味"],
            swatchColors: [
                Color(red: 0.78, green: 0.62, blue: 0.55),
                Color(red: 0.70, green: 0.54, blue: 0.48),
                Color(red: 0.62, green: 0.46, blue: 0.42)
            ]
        )
    ]

    static let defaultTasks: [UserTaskItem] = [
        UserTaskItem(title: "完成第一次面部扫描", reward: 50, isCompleted: true),
        UserTaskItem(title: "扫描一件化妆品入陈列柜", reward: 20, isCompleted: false),
        UserTaskItem(title: "完成一次上妆教学", reward: 10, isCompleted: false),
        UserTaskItem(title: "连续三天打开 App", reward: 5, isCompleted: false)
    ]
}
