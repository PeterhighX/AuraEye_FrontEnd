import SwiftUI
import UIKit

struct UserProfileDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: AppSession
    @Binding var path: NavigationPath
    @State private var user: UserProfile?
    @State private var capturedPortrait: UIImage?
    @State private var showsCamera = false
    @State private var showsPhotoLibrary = false
    @State private var showsSourcePicker = false
    @State private var imageSource: UIImagePickerController.SourceType = .camera
    @State private var isAnalyzing = false
    @State private var analysisErrorMessage: String?
    @State private var showsProfileMenu = false

    private let userRepository = UserRepository()
    private let faceAnalysisService: any FaceAnalysisServicing = AccountAwareFaceAnalysisService()

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                profileHeader
                    .padding(.top, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        profileCard
                        analysisSection
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 12)
                }

                bottomActions
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .fullScreenCover(isPresented: $showsCamera) {
            CameraPickerView(
                onImageCaptured: generateVirtualAvatar,
                sourceType: imageSource,
                cameraDevice: .front
            )
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showsPhotoLibrary) {
            OfficialGalleryContainer(onSelection: generateVirtualAvatar)
        }
        .confirmationDialog("档案操作", isPresented: $showsProfileMenu, titleVisibility: .visible) {
            Button("重新上传照片") {
                showsSourcePicker = true
            }
            Button("重新分析") {
                runAnalysis()
            }
            Button("取消", role: .cancel) {}
        }
        .alert(
            "分析未完成",
            isPresented: Binding(
                get: { analysisErrorMessage != nil },
                set: { if !$0 { analysisErrorMessage = nil } }
            )
        ) {
            Button("重新选择") {
                analysisErrorMessage = nil
                showsSourcePicker = true
            }
            Button("取消", role: .cancel) {
                analysisErrorMessage = nil
            }
        } message: {
            Text(analysisErrorMessage ?? "面部分析暂时未完成，请重新选择照片。")
        }
        .overlay {
            if showsSourcePicker {
                MediaSourceDialog(
                    showsCamera: !usesFixedDemoGallery,
                    onCamera: {
                        imageSource = .camera
                        showsSourcePicker = false
                        showsCamera = true
                    },
                    onLibrary: {
                        showsSourcePicker = false
                        showsPhotoLibrary = true
                    },
                    onCancel: { showsSourcePicker = false }
                )
            }
        }
        .onAppear { loadUser() }
    }

    // MARK: - Fixed top bar

    private var profileHeader: some View {
        HStack(spacing: 8) {
            Button(action: { dismiss() }) {
                Image(systemName: AppTheme.Symbol.back)
                    .font(.system(size: 19, weight: .medium))
                    .frame(width: 30, height: 30)
            }

            Text("我的档案")
                .font(.system(size: 20, weight: .regular, design: .rounded))
                .foregroundStyle(AppTheme.ColorToken.textPrimary.opacity(0.8))
                .frame(height: 30)

            Spacer(minLength: 8)

            Button(action: { showsProfileMenu = true }) {
                Image("ProfileMenu")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("档案操作")

            portraitImage
                .frame(width: 36, height: 36)
                .clipShape(Circle())
        }
        .foregroundStyle(AppTheme.ColorToken.textPrimary)
        .padding(.horizontal, 16)
        .frame(height: 44)
    }

    // MARK: - Profile summary

    private var profileCard: some View {
        HStack(alignment: .bottom, spacing: 18) {
            portraitImage
                .frame(width: 111, height: 148)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .offset(y: -16)

            VStack(alignment: .trailing, spacing: 0) {
                Text("Anna Chen")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppTheme.ColorToken.textPrimary)
                    .lineLimit(1)

                Text("整体评价")
                    .padding(.top, 4)

                Text("干净素颜感 · 原生温柔淡颜系")
                    .lineLimit(1)

                Spacer(minLength: 8)

                HStack(spacing: 8) {
                    profileActionButton(title: "重新上传", color: AppTheme.ColorToken.accentCoral) {
                        showsSourcePicker = true
                    }

                    profileActionButton(
                        title: isAnalyzing ? "分析中…" : "开始分析",
                        color: AppTheme.ColorToken.textPrimary.opacity(0.25)
                    ) {
                        runAnalysis()
                    }
                    .disabled(isAnalyzing)
                }
            }
            .font(.system(size: 14, weight: .thin))
            .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.2))
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.vertical, 14)
        }
        .frame(height: 148)
        .padding(.horizontal, 16)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.hero)
                .fill(Color(red: 1.0, green: 0.93, blue: 0.91).opacity(0.40))
        }
        .shadow(color: Color(red: 0.3, green: 0.3, blue: 0.3).opacity(0.09), radius: 4, y: 2)
        .padding(.horizontal, 16)
    }

    private var portraitImage: some View {
        Group {
            if let capturedPortrait {
                Image(uiImage: capturedPortrait)
                    .resizable()
                    .scaledToFill()
            } else if let path = user?.userPortraitPath {
                LocalImageView(
                    storedPath: path,
                    assetName: "AvatarUser",
                    systemImage: "person.crop.circle.fill"
                )
            } else {
                Image("AvatarUser")
                    .resizable()
                    .scaledToFill()
            }
        }
    }

    private func profileActionButton(
        title: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .tracking(1)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Analysis

    private var analysisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            analysisText
                .font(.system(size: 14, weight: .thin))
                .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.2))
                .lineSpacing(6)

            VStack(alignment: .leading, spacing: 8) {
                Label("色彩标签", systemImage: "circle.fill")
                    .labelStyle(ProfileBulletLabelStyle())

                Text("肤色")
                colorSwatches([
                    Color(red: 0.96, green: 0.83, blue: 0.76),
                    Color(red: 0.91, green: 0.73, blue: 0.62)
                ])

                Text("瞳色")
                colorSwatches([
                    Color(red: 0.22, green: 0.15, blue: 0.10),
                    Color(red: 0.18, green: 0.12, blue: 0.10)
                ])
            }
            .font(.system(size: 14, weight: .thin))
            .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.2))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }

    private var analysisText: Text {
        Text("✨ 整体轮廓分析\n")
        + Text("整体为鹅蛋脸，脸型线条流畅柔和，下颌角圆润无棱角，长宽比例均衡。面部留白适中，肤色属于粉皮（偏白），观感干净清爽。\n")
        + Text("✨ 眉眼细节诊断\n")
        + Text("推荐一字眉，毛流感自然，贴合素颜感。眉眼间距适中，眼型是杏眼，眼尾平缓上扬。眼皮为双眼皮，自然卧蚕适中，微笑卧蚕较深。虽黑眼圈较重且上眼睑轻微浮肿，但记得贴双眼皮贴哦，能瞬间放大双眼。\n")
        + Text("✨ 风格明星推荐\n")
        + Text("眼距标准，五官呈小量感，适合少女型、少年型、自然型妆容，可参考周冬雨、陈都灵、IU的清透风格。")
    }

    private func colorSwatches(_ colors: [Color]) -> some View {
        HStack(spacing: 14) {
            ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .frame(maxWidth: .infinity)
                    .frame(height: 23)
            }
        }
    }

    // MARK: - Bottom actions

    private var bottomActions: some View {
        HStack(spacing: 14) {
            Button(action: { runAnalysis() }) {
                bottomButtonLabel(isAnalyzing ? "分析中…" : "重新分析")
                    .foregroundStyle(AppTheme.ColorToken.textSecondary)
                    .background(Color.white.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.button))
            }
            .disabled(isAnalyzing)

            Button {
                path.append(session.routeForQuickStart())
            } label: {
                bottomButtonLabel("继续上妆")
                    .foregroundStyle(.white)
                    .background(AppTheme.ColorToken.buttonPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.button))
            }
        }
    }

    private func bottomButtonLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .regular, design: .rounded))
            .tracking(1)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .shadow(color: Color(red: 0.3, green: 0.3, blue: 0.3).opacity(0.09), radius: 4, y: 2)
    }

    private func loadUser() {
        user = try? userRepository.currentUser()
    }

    private var usesFixedDemoGallery: Bool {
        SessionManager.shared.context?.features.galleryMode == .fixedDemo
    }

    private func runAnalysis() {
        guard !isAnalyzing else { return }

        if !usesFixedDemoGallery, let capturedPortrait {
            generateVirtualAvatar(from: capturedPortrait)
            return
        }

        guard let storedPath = user?.userPortraitPath,
              let data = LocalMediaStore.loadData(fromStoredPath: storedPath),
              let contentType = LocalMediaStore.contentType(forStoredPath: storedPath),
              (!usesFixedDemoGallery || isCanonicalDemoPortrait(data)),
              let input = try? VisionImageInput(photoData: data, contentType: contentType) else {
            analysisErrorMessage = usesFixedDemoGallery
                ? "请从演示相册重新选择面部照片"
                : "原始面部照片无法读取，请重新选择照片。"
            return
        }

        Task { await generateVirtualAvatar(from: input) }
    }

    private func isCanonicalDemoPortrait(_ data: Data, bundle: Bundle = .main) -> Bool {
        guard let url = bundle.url(
            forResource: "demo_face_portrait_001",
            withExtension: "jpg",
            subdirectory: "DemoFixtures"
        ), let canonicalData = try? Data(contentsOf: url, options: [.mappedIfSafe]) else {
            return false
        }
        return data == canonicalData
    }

    private func generateVirtualAvatar(from image: UIImage) {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        Task {
            defer { isAnalyzing = false }
            guard var profile = try? userRepository.currentUser() else { return }
            var failureStage = VisionRequestStage.processingResult
            do {
                let result = try await faceAnalysisService.analyze(
                    image: image,
                    userId: profile.userId
                )

                failureStage = .savingProfile
                profile.userPortraitPath = result.portraitPath
                profile.userFileJSON = result.profileJSON
                try userRepository.update(profile)
                capturedPortrait = nil
                user = profile
            } catch {
                analysisErrorMessage = visionFailureMessage(error, fallbackStage: failureStage)
            }
        }
    }

    private func generateVirtualAvatar(from input: VisionImageInput) async {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        defer { isAnalyzing = false }
        guard var profile = try? userRepository.currentUser() else { return }
        var failureStage = VisionRequestStage.processingResult
        do {
            let result = try await faceAnalysisService.analyze(
                input: input,
                userId: profile.userId
            )
            failureStage = .savingProfile
            profile.userPortraitPath = result.portraitPath
            profile.userFileJSON = result.profileJSON
            try userRepository.update(profile)
            capturedPortrait = nil
            user = profile
        } catch {
            analysisErrorMessage = visionFailureMessage(error, fallbackStage: failureStage)
        }
    }
}

private struct ProfileBulletLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 9) {
            configuration.icon
                .font(.system(size: 4))
            configuration.title
        }
    }
}

#Preview {
    NavigationStack {
        UserProfileDetailView(
            session: AppSession(),
            path: .constant(NavigationPath())
        )
    }
}
