import SwiftUI
import UIKit

struct FirstTimeUseView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: AppSession
    @Binding var path: NavigationPath

    @State private var viewModel: FirstTimeUseViewModel
    @State private var showCamera = false
    @State private var showImageSourcePicker = false
    @State private var imageSource: UIImagePickerController.SourceType = .camera

    init(session: AppSession, path: Binding<NavigationPath>) {
        self.session = session
        _path = path
        _viewModel = State(initialValue: FirstTimeUseViewModel(session: session))
    }

    var body: some View {
        ZStack {
            HomeBackgroundView()

            VStack(spacing: 0) {
                MakeupFlowHeaderView(title: "妆容预览", usesPreviewAssets: true) {
                    dismiss()
                }
                .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 24) {
                        WeatherSummaryCard(
                            aiMessage: """
                            今日天气多云，气温26℃，紫外线指数偏弱，可以放心大胆的出门哦！
                            您是第一次使用APP，推荐先完善用户档案再开始化妆，下面是推荐的妆容！！
                            """,
                            showFirstTimeHint: true
                        )

                        TipBarView(tips: ["眼周油脂盖住之后后续颜色更容易显色。"])

                        ForEach(viewModel.steps) { step in
                            OnboardingStepRow(
                                step: step,
                                isActionEnabled: viewModel.canTap(step)
                            ) {
                                handleStepTap(step)
                            }
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                        }
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 80)
                    .animation(AppTheme.Motion.stepSpring, value: viewModel.steps)
                }
            }

            VStack {
                Spacer()
                if viewModel.hasStartedProgress {
                    statusBar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear { viewModel.reload() }
        .onChange(of: viewModel.pendingNavigation) { _, navigation in
            switch navigation {
            case .makeupPreview:
                path.append(AppRoute.makeupPreview)
                viewModel.clearNavigation()
            case .none:
                break
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPickerView(
                onImageCaptured: viewModel.handleCameraCapture,
                sourceType: imageSource,
                cameraDevice: viewModel.cameraTarget == .face ? .front : .rear
            )
        }
        .confirmationDialog(
            viewModel.cameraTarget == .face ? "扫描脸部" : "扫描化妆品",
            isPresented: $showImageSourcePicker,
            titleVisibility: .visible
        ) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("拍照") {
                    imageSource = .camera
                    showCamera = true
                }
            }
            Button("从相册选择") {
                imageSource = .photoLibrary
                showCamera = true
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("可以调用设备摄像头，也可以选择设备上已经下载的图片。")
        }
        .overlay {
            if let product = viewModel.pendingProduct {
                productConfirmation(product)
            }
        }
    }

    private var statusBar: some View {
        HStack(spacing: 0) {
            Text(statusTag)
                .font(AppTheme.Typography.statusBar)
                .foregroundStyle(AppTheme.ColorToken.textPrimary)
                .padding(.horizontal, 13)
                .frame(height: 36)
                .background(AppTheme.ColorToken.accentCoral)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card))

            if viewModel.isProcessing {
                ProgressView()
                    .controlSize(.small)
                    .padding(.leading, 8)
            }

            Text(viewModel.statusText)
                .font(AppTheme.Typography.statusBar)
                .foregroundStyle(AppTheme.ColorToken.textPrimary)
                .lineLimit(1)
                .padding(.leading, 8)
                .animation(AppTheme.Motion.statusFade, value: viewModel.statusText)

            Spacer()

            ProgressView(value: viewModel.preparationProgress)
                .tint(AppTheme.ColorToken.accentCoral)
                .frame(width: 72)
        }
        .padding(4)
        .background(Color.white.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card))
    }

    private var statusTag: String {
        if let active = viewModel.steps.first(where: { $0.isActive && !$0.isCompleted }) {
            switch active.stepKey {
            case .userProfile: return "扫描脸部，"
            case .cosmetics: return "扫描化妆品，"
            case .makeupGenerate: return "妆容生成，"
            }
        }
        return "扫描完成，"
    }

    private func handleStepTap(_ step: OnboardingStep) {
        if let target = viewModel.cameraTargetForStep(step) {
            viewModel.cameraTarget = target
            showImageSourcePicker = true
            return
        }
        if step.stepKey == .makeupGenerate, step.isActive {
            viewModel.generateMakeup()
        }
    }

    private func productConfirmation(_: CosmeticsRecognitionResult) -> some View {
        ZStack {
            Color.black.opacity(0.58).ignoresSafeArea()

            Image("ProductAddPrompt")
                .resizable()
                .scaledToFit()
                .frame(width: 300, height: 364)
                .overlay {
                    VStack(spacing: 10) {
                        Spacer()

                        Button(action: viewModel.rejectPendingProduct) {
                            Color.clear
                                .contentShape(RoundedRectangle(cornerRadius: 25))
                        }
                        .frame(height: 50)
                        .accessibilityLabel("拒绝")

                        Button(action: viewModel.confirmPendingProduct) {
                            Color.clear
                                .contentShape(RoundedRectangle(cornerRadius: 25))
                        }
                        .frame(height: 50)
                        .accessibilityLabel("添加")
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                }
                .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
        }
    }
}

#Preview {
    NavigationStack {
        FirstTimeUseView(session: AppSession(), path: .constant(NavigationPath()))
    }
}
