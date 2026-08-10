import SwiftUI
import UIKit

struct FirstTimeUseView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: AppSession
    @Binding var path: NavigationPath

    @State private var viewModel: FirstTimeUseViewModel
    @State private var showCamera = false
    @State private var showImageSourcePicker = false
    @State private var showPhotoLibrary = false
    @State private var imageSource: UIImagePickerController.SourceType = .camera
    @State private var loadingIconRotation = 0.0
    @State private var loadingTextPulse = false

    init(session: AppSession, path: Binding<NavigationPath>) {
        self.session = session
        _path = path
        _viewModel = State(initialValue: FirstTimeUseViewModel(session: session))
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                MakeupFlowHeaderView(title: "妆容预览", usesPreviewAssets: true) {
                    dismiss()
                }
                .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 24) {
                        Image("OnboardingStepsWeatherComposed")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel("首次使用步骤天气卡片")

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
                if viewModel.showsCaptureProgress {
                    statusBar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            viewModel.reload()
        }
        .onChange(of: viewModel.pendingNavigation) { _, navigation in
            switch navigation {
            case .onboardingCabinet:
                path.append(AppRoute.onboardingCabinet)
                viewModel.clearNavigation()
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
        .fullScreenCover(isPresented: $showPhotoLibrary) {
            OfficialGalleryContainer(onSelection: viewModel.handleSelectedInput)
        }
        .alert(
            viewModel.recognitionErrorTitle,
            isPresented: Binding(
                get: { viewModel.recognitionErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.clearRecognitionError()
                    }
                }
            )
        ) {
            Button("重新识别") {
                viewModel.clearRecognitionError()
                showImageSourcePicker = true
            }
            Button("取消", role: .cancel) {
                viewModel.clearRecognitionError()
            }
        } message: {
            Text(
                viewModel.recognitionErrorMessage
                    ?? "未能确认所选图片是化妆品，请调整角度后重新拍摄。"
            )
        }
        .overlay {
            if showImageSourcePicker {
                MediaSourceDialog(
                    onCamera: {
                        imageSource = .camera
                        showImageSourcePicker = false
                        showCamera = true
                    },
                    onLibrary: {
                        showImageSourcePicker = false
                        showPhotoLibrary = true
                    },
                    onCancel: { showImageSourcePicker = false }
                )
            } else if let product = viewModel.pendingProduct {
                productConfirmation(product)
            } else if viewModel.processingStage == .makeup {
                generationWaitingOverlay
            }
        }
    }

    private var generationWaitingOverlay: some View {
        ZStack {
            Color.white.opacity(0.96)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                Image("PracticeToolIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .rotationEffect(.degrees(loadingIconRotation))

                Text("正在生成专属妆容…")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.ColorToken.textPrimary)
                .scaleEffect(loadingTextPulse ? 1.012 : 0.995)
                .offset(y: loadingTextPulse ? -1 : 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            loadingIconRotation = 0
            loadingTextPulse = false
            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                loadingIconRotation = 360
            }
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                loadingTextPulse = true
            }
        }
        .transition(.opacity)
        .zIndex(20)
    }

    private var statusBar: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 1, green: 154 / 255, blue: 124 / 255))
                .frame(
                    width: 362 * min(max(viewModel.profileAnalysisProgress, 0), 1),
                    height: 36
                )
                .overlay(alignment: .trailing) {
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.48), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 38)
                    .offset(x: loadingTextPulse ? 20 : -42)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))

            HStack(spacing: 8) {
                Text(statusTag)
                    .font(AppTheme.Typography.statusBar)
                    .foregroundStyle(AppTheme.ColorToken.textPrimary)

                Text(viewModel.statusText)
                    .font(AppTheme.Typography.statusBar)
                    .foregroundStyle(AppTheme.ColorToken.textPrimary)
                    .lineLimit(1)
                    .animation(AppTheme.Motion.statusFade, value: viewModel.statusText)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
        }
        .padding(4)
        .frame(width: 370, height: 44)
        .background(Color.white.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color(red: 38 / 255, green: 38 / 255, blue: 38 / 255).opacity(0.25), lineWidth: 0.1)
        }
        .shadow(color: Color.black.opacity(0.09), radius: 2, y: 2)
        .animation(
            .easeInOut(duration: 0.22),
            value: viewModel.profileAnalysisProgress
        )
        .onAppear {
            loadingTextPulse = false
            withAnimation(.linear(duration: 1.05).repeatForever(autoreverses: false)) {
                loadingTextPulse = true
            }
        }
    }

    private var statusTag: String {
        switch viewModel.processingStage {
        case .profile:
            return "扫描脸部，"
        case .cosmetics:
            return "扫描化妆品，"
        case .makeup:
            return "选择妆容，"
        case .none:
            break
        }

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
        if step.stepKey == .cosmetics,
           !session.onboardingCosmeticCategories.isEmpty,
           !session.hasAllRequiredOnboardingCosmetics {
            path.append(AppRoute.onboardingCabinet)
            return
        }

        if let target = viewModel.cameraTargetForStep(step) {
            viewModel.cameraTarget = target
            showImageSourcePicker = true
            return
        }
        if step.stepKey == .makeupGenerate, step.isActive {
            viewModel.generateMakeup()
        }
    }

    private func productConfirmation(_ product: CosmeticsRecognitionResult) -> some View {
        ZStack {
            Color.black.opacity(0.58).ignoresSafeArea()

            VStack(spacing: 16) {
                Text(product.displayName)
                    .font(.title3)
                    .frame(maxWidth: .infinity, alignment: .leading)

                LocalImageView(storedPath: product.previewPath)
                    .frame(width: 160, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Text(product.category)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color(.secondarySystemFill), in: Capsule())

                Button("拒绝", action: viewModel.rejectPendingProduct)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(.systemGray5), in: Capsule())

                Button("添加", action: viewModel.confirmPendingProduct)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        Color(red: 104 / 255, green: 106 / 255, blue: 219 / 255),
                        in: Capsule()
                    )
            }
            .padding(24)
            .frame(width: 300)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 32)
            )
            .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
        }
    }
}

#Preview {
    NavigationStack {
        FirstTimeUseView(session: AppSession(), path: .constant(NavigationPath()))
    }
}
