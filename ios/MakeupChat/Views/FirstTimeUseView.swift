import SwiftUI
import UIKit

struct FirstTimeUseView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: AppSession

    @State private var showCamera = false
    @State private var isAnalyzing = false
    @State private var statusText = "扫描脸部，建立用户档案中……"

    private let userRepository = UserRepository()

    var body: some View {
        ZStack {
            GradientBackgroundView()

            ScrollView {
                VStack(spacing: 24) {
                    MakeupFlowHeaderView(title: "妆容预览") {
                        dismiss()
                    }

                    WeatherSummaryCard(
                        aiMessage: """
                        今日天气多云，气温26℃，紫外线指数偏弱，可以放心大胆的出门哦！
                        您是第一次使用APP，推荐先完善用户档案再开始化妆，下面是推荐的妆容！！
                        """,
                        showFirstTimeHint: true
                    )

                    TipBarView(tipText: "眼周油脂盖住之后后续颜色更容易显色。")

                    OnboardingStepRow(
                        stepNumber: 1,
                        title: "用户档案",
                        subtitle: session.hasScannedFace
                            ? "✨ 面部扫描完成，闪闪正在整理你的档案"
                            : "✨ 闪闪正在用火眼金睛分析你的面部特征哦",
                        buttonTitle: session.hasScannedFace ? "已完成" : "扫描脸部",
                        systemImage: "person.crop.circle",
                        isActive: !session.hasScannedFace,
                        isCompleted: session.hasScannedFace
                    ) {
                        showCamera = true
                    }

                    OnboardingStepRow(
                        stepNumber: 2,
                        title: "化妆品",
                        subtitle: "✨ 闪闪正在认真翻看宝子自己有哪些化妆品……",
                        buttonTitle: "扫描化妆品",
                        systemImage: "shippingbox.fill",
                        isActive: session.hasScannedFace,
                        isCompleted: false
                    ) {}

                    OnboardingStepRow(
                        stepNumber: 3,
                        title: "妆容生成",
                        subtitle: "✨ 正在为你规划最不容易手残的保姆级步骤……",
                        buttonTitle: "开始生成",
                        systemImage: "sparkles",
                        isActive: false,
                        isCompleted: false
                    ) {}
                }
                .padding(.top, 8)
                .padding(.bottom, 80)
            }

            VStack {
                Spacer()
                statusBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPickerView { image in
                handleCapturedImage(image)
            }
        }
    }

    private var statusBar: some View {
        HStack(spacing: 0) {
            Text(session.hasScannedFace ? "扫描完成，" : "扫描脸部，")
                .font(.system(size: 12, weight: .light))
                .foregroundStyle(Color(red: 0.15, green: 0.15, blue: 0.15))
                .tracking(1)
                .padding(.horizontal, 13)
                .frame(height: 36)
                .background(Color(red: 1.0, green: 0.60, blue: 0.49))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            Text(statusText)
                .font(.system(size: 12, weight: .light))
                .foregroundStyle(Color(red: 0.15, green: 0.15, blue: 0.15))
                .tracking(1)
                .lineLimit(1)
                .padding(.leading, 8)

            Spacer()
        }
        .padding(4)
        .background(Color.white.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color(red: 0.15, green: 0.15, blue: 0.15).opacity(0.25), lineWidth: 0.1)
        )
    }

    private func handleCapturedImage(_ image: UIImage) {
        isAnalyzing = true
        statusText = "建立用户档案中……"

        Task { @MainActor in
            do {
                let path = try FaceScanService.savePortrait(image)
                session.markFaceScanned(imagePath: path)

                if var user = try? userRepository.currentUser() {
                    user.userPortraitPath = path
                    try? userRepository.update(user)
                }

                statusText = "用户档案建立完成！"
            } catch {
                statusText = "保存失败，请重试"
            }
            isAnalyzing = false
        }
    }
}

#Preview {
    NavigationStack {
        FirstTimeUseView(session: AppSession())
    }
}
