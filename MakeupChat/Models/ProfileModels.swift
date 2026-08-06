import Foundation
import SwiftUI

struct MakeupHistoryItem: Identifiable {
    let id: UUID
    let title: String
    let imageAssetName: String
    let makeupTime: String
    let makeupCount: String
    let swatchColors: [Color]

    init(
        id: UUID = UUID(),
        title: String,
        imageAssetName: String,
        makeupTime: String,
        makeupCount: String,
        swatchColors: [Color]
    ) {
        self.id = id
        self.title = title
        self.imageAssetName = imageAssetName
        self.makeupTime = makeupTime
        self.makeupCount = makeupCount
        self.swatchColors = swatchColors
    }
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
            imageAssetName: "HomeLookClearFocus",
            makeupTime: "今天 08:42",
            makeupCount: "第 8 次",
            swatchColors: [
                Color(red: 0.91, green: 0.78, blue: 0.70),
                Color(red: 0.85, green: 0.72, blue: 0.65),
                Color(red: 0.77, green: 0.65, blue: 0.52)
            ]
        ),
        MakeupHistoryItem(
            title: "中式温婉",
            imageAssetName: "HomeLookWarmFocus",
            makeupTime: "7月26日 19:10",
            makeupCount: "第 7 次",
            swatchColors: [
                Color(red: 0.82, green: 0.68, blue: 0.58),
                Color(red: 0.74, green: 0.58, blue: 0.50),
                Color(red: 0.66, green: 0.50, blue: 0.44)
            ]
        ),
        MakeupHistoryItem(
            title: "气质港风",
            imageAssetName: "HomeLookHongKongFocus",
            makeupTime: "7月22日 20:15",
            makeupCount: "第 6 次",
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
