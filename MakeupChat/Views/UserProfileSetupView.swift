import SwiftUI
import UIKit

struct UserProfileSetupView: View {
    @Bindable var session: AppSession
    @Binding var path: NavigationPath

    @State private var viewModel = UserProfileSetupViewModel()
    @State private var showSourcePicker = false
    @State private var showImagePicker = false
    @State private var imageSource: UIImagePickerController.SourceType = .camera
    @State private var logoRotation = 0.0
    @State private var textPulse = false

    var body: some View {
        ZStack {
            GradientBackgroundView()

            VStack(spacing: 18) {
                Image(systemName: "person.crop.rectangle")
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(AppTheme.ColorToken.accentCoral)

                Text("创建你的用户档案")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("拍摄清晰正脸照片，或从相册选择已经下载的照片。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("选择照片") {
                    showSourcePicker = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(AppTheme.ColorToken.buttonPrimary)
            }
            .padding(28)

            if viewModel.isAnalyzing {
                analysisOverlay
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            guard !viewModel.isAnalyzing else { return }
            showSourcePicker = true
        }
        .confirmationDialog(
            "创建用户档案",
            isPresented: $showSourcePicker,
            titleVisibility: .visible
        ) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("拍摄正脸照片") {
                    imageSource = .camera
                    showImagePicker = true
                }
            }

            Button("从相册选择") {
                imageSource = .photoLibrary
                showImagePicker = true
            }

            Button("取消", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showImagePicker) {
            CameraPickerView(
                onImageCaptured: handleSelectedImage,
                sourceType: imageSource,
                cameraDevice: .front
            )
        }
        .alert(
            "分析未完成",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.clearError() } }
            )
        ) {
            Button("重新选择") {
                showSourcePicker = true
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var analysisOverlay: some View {
        ZStack {
            Color.white.opacity(0.94)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                logoMark
                    .rotationEffect(.degrees(logoRotation))
                    .onAppear {
                        withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                            logoRotation = 360
                        }
                    }

                Text("AuraAye 沐瞳")
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.ColorToken.textPrimary)

                Text("正在分析你的面部特征，请稍候…")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .scaleEffect(textPulse ? 1.015 : 0.995)
                    .offset(y: textPulse ? -1 : 1)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                            textPulse = true
                        }
                    }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("正在分析面部特征")
        }
        .transition(.opacity)
    }

    private var logoMark: some View {
        Image("AuraAyeLogo")
            .resizable()
            .scaledToFit()
            .frame(width: 132, height: 132)
            .frame(width: 132, height: 94, alignment: .top)
            .clipped()
            .accessibilityHidden(true)
    }

    private func handleSelectedImage(_ image: UIImage) {
        Task {
            let succeeded = await viewModel.analyze(image, session: session)
            guard succeeded else { return }
            path.removeLast()
            path.append(AppRoute.userProfile)
        }
    }
}

#Preview {
    NavigationStack {
        UserProfileSetupView(
            session: AppSession(),
            path: .constant(NavigationPath())
        )
    }
}
