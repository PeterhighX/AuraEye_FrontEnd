import SwiftUI
import UIKit

struct UserProfileSetupView: View {
    @Bindable var session: AppSession
    @Binding var path: NavigationPath

    @State private var viewModel = UserProfileSetupViewModel()
    @State private var showSourcePicker = false
    @State private var showImagePicker = false
    @State private var showPhotoLibrary = false
    @State private var imageSource: UIImagePickerController.SourceType = .camera

    var body: some View {
        ZStack {
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
        .fullScreenCover(isPresented: $showImagePicker) {
            CameraPickerView(
                onImageCaptured: handleSelectedImage,
                sourceType: imageSource,
                cameraDevice: .front
            )
        }
        .fullScreenCover(isPresented: $showPhotoLibrary) {
            OfficialGalleryContainer(onSelection: handleSelectedInput)
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
        .overlay {
            if showSourcePicker {
                MediaSourceDialog(
                    showsCamera: !usesFixedDemoGallery,
                    onCamera: {
                        imageSource = .camera
                        showSourcePicker = false
                        showImagePicker = true
                    },
                    onLibrary: {
                        showSourcePicker = false
                        showPhotoLibrary = true
                    },
                    onCancel: { showSourcePicker = false }
                )
            }
        }
    }

    private var usesFixedDemoGallery: Bool {
        SessionManager.shared.context?.features.galleryMode == .fixedDemo
    }

    private var analysisOverlay: some View {
        OperationTransitionOverlay(
            message: "正在分析你的面部特征，请稍候…",
            tips: TipLibrary.profileTips
        )
    }

    private func handleSelectedImage(_ image: UIImage) {
        Task {
            let succeeded = await viewModel.analyze(image, session: session)
            guard succeeded else { return }
            path.removeLast()
            path.append(AppRoute.userProfile)
        }
    }

    private func handleSelectedInput(_ input: VisionImageInput) async {
        let succeeded = await viewModel.analyze(input, session: session)
        guard succeeded else { return }
        path.removeLast()
        path.append(AppRoute.userProfile)
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
