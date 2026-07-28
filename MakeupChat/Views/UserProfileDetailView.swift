import SwiftUI
import UIKit

struct UserProfileDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var user: UserProfile?
    @State private var capturedPortrait: UIImage?
    @State private var showsCamera = false
    @State private var isAnalyzing = false
    @State private var showsProfileMenu = false

    private let userRepository = UserRepository()
    private let faceAnalysisService: any FaceAnalysisServicing = LocalFaceAnalysisService()

    var body: some View {
        ZStack {
            ProfileDetailBackgroundView()

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
            CameraPickerView { image in
                generateVirtualAvatar(from: image)
            }
            .ignoresSafeArea()
        }
        .confirmationDialog("档案操作", isPresented: $showsProfileMenu, titleVisibility: .visible) {
            Button("重新上传照片") {
                showsCamera = true
            }
            Button("重新分析") {
                runAnalysis()
            }
            Button("取消", role: .cancel) {}
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
                        showsCamera = true
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

            NavigationLink(value: AppRoute.makeupPreview) {
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

    private func runAnalysis() {
        guard !isAnalyzing else { return }
        let image: UIImage?
        if let capturedPortrait {
            image = capturedPortrait
        } else if let path = user?.userPortraitPath {
            image = LocalMediaStore.loadImage(fromStoredPath: path)
        } else {
            image = nil
        }
        guard let image else { return }
        generateVirtualAvatar(from: image)
    }

    private func generateVirtualAvatar(from image: UIImage) {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        Task {
            defer { isAnalyzing = false }
            guard var profile = try? userRepository.currentUser() else { return }
            guard let result = try? await faceAnalysisService.analyze(
                image: image,
                userId: profile.userId
            ) else { return }

            profile.userPortraitPath = result.portraitPath
            profile.userFileJSON = result.profileJSON
            try? userRepository.update(profile)
            capturedPortrait = nil
            user = profile
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
        UserProfileDetailView()
    }
}
