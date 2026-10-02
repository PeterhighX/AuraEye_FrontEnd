import SwiftUI
import UIKit

@MainActor
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
    @State private var showsPortraitConsent = false
    @State private var isGeneratingPortrait = false
    @State private var portraitRequestID: String?
    @State private var quickStartMessage: String?

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
        .confirmationDialog(
            "生成透明头像",
            isPresented: $showsPortraitConsent,
            titleVisibility: .visible
        ) {
            Button("同意使用本次照片生成头像与教程人物图") {
                requestPortrait()
            }
            Button("暂不生成", role: .cancel) {}
        } message: {
            Text("将本次面部分析使用的照片去除背景，生成仅本账号可读取的透明肖像。")
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
        .alert("上妆记录未就绪", isPresented: Binding(
            get: { quickStartMessage != nil },
            set: { if !$0 { quickStartMessage = nil } }
        )) {
            Button("重试") {
                Task {
                    if session.isDemoAccount { await session.openDemoRun() }
                    else { await session.business.refreshGrowth() }
                }
            }
        } message: {
            Text(quickStartMessage ?? "请稍后重试。")
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
        .task {
            await session.business.refreshProfile()
            if session.shouldOfferPortraitConsent,
               canGeneratePortrait,
               session.business.visualProfile?.portrait == nil {
                session.shouldOfferPortraitConsent = false
                showsPortraitConsent = true
            }
        }
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
                Text(session.authenticatedAccount?.displayName ?? "用户")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppTheme.ColorToken.textPrimary)
                    .lineLimit(1)

                Text("整体评价")
                    .padding(.top, 4)

                Text(session.business.visualProfile == nil
                    ? "分析报告尚未生成"
                    : (session.business.visualProfile?.narrative?.overall ?? "面部分析已完成"))
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

                if let profile = session.business.visualProfile {
                    Text(portraitStatus(profile.portrait))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if canGeneratePortrait,
                       (profile.portrait == nil || profile.portrait?.status == "failed") {
                        Button(isGeneratingPortrait ? "生成中…" : "生成透明头像") {
                            showsPortraitConsent = true
                        }
                        .font(.caption)
                        .disabled(isGeneratingPortrait)
                    }
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
            if let data = session.business.avatarData,
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFill()
                    .foregroundStyle(.secondary)
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
            if let profile = session.business.visualProfile {
                Text(profile.resultSource == "remote_provider" ? "真实面部分析" : "演示分析结果")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            analysisText
                .font(.system(size: 14, weight: .thin))
                .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.2))
                .lineSpacing(6)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }

    private var analysisText: Text {
        guard let profile = session.business.visualProfile else {
            return Text(session.business.profileError.map { "档案暂不可用：\($0)" } ?? "尚无面部分析报告。")
        }
        guard let narrative = profile.narrative else {
            return Text(profile.narrativeStatus == "pending"
                ? "分析已完成，文字报告生成中。"
                : "面部分析已完成，结果已保存；详细文字报告暂不可用。")
        }
        return Text("✨ 整体轮廓分析\n")
            + Text("\(narrative.overall ?? "暂无描述")\n")
            + Text("✨ 眉眼细节诊断\n")
            + Text("\(narrative.eyeDetails ?? "暂无描述")\n")
            + Text("✨ 风格推荐\n")
            + Text(narrative.styleRecommendation ?? "暂无推荐")
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
                if let route = session.routeForQuickStart() {
                    path.append(route)
                } else {
                    quickStartMessage = session.isDemoAccount
                        ? (session.demoRunError ?? "正在打开演示流程，请稍后重试。")
                        : (session.business.growthError ?? "正在读取上妆记录，请稍后重试。")
                }
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

    private func portraitStatus(_ portrait: UserPortraitDTO?) -> String {
        guard let portrait else { return "尚未生成透明头像" }
        switch portrait.status {
        case "queued", "running": return "透明头像生成中"
        case "succeeded": return portrait.hasAlpha ? "透明头像已更新" : "头像结果未通过透明度校验"
        case "failed": return portrait.error?.message ?? "透明头像生成失败"
        default: return "透明头像状态待同步"
        }
    }

    private func requestPortrait() {
        guard let version = session.business.visualProfile?.profileVersion,
              canGeneratePortrait,
              !isGeneratingPortrait else { return }
        if session.business.visualProfile?.portrait?.status == "failed" {
            portraitRequestID = nil
        }
        let requestID = portraitRequestID ?? UUID().uuidString
        portraitRequestID = requestID
        isGeneratingPortrait = true
        Task {
            defer { isGeneratingPortrait = false }
            do {
                let ticket = try await BusinessDataService.shared.generatePortrait(
                    requestID: requestID, profileVersion: version
                )
                for _ in 0..<200 {
                    await session.business.refreshProfile()
                    guard let portrait = session.business.visualProfile?.portrait else { return }
                    if portrait.status == "succeeded" || portrait.status == "failed" { return }
                    try await Task.sleep(for: .milliseconds(max(500, min(ticket.pollAfterMS, 10_000))))
                }
            } catch {
                analysisErrorMessage = error.localizedDescription
            }
        }
    }

    private var usesFixedDemoGallery: Bool {
        SessionManager.shared.context?.features.galleryMode == .fixedDemo
    }

    private var canGeneratePortrait: Bool {
        guard let profile = session.business.visualProfile else { return false }
        if session.isDemoAccount {
            return session.demoRun?.completed.contains("face_analysis") == true
                && profile.resultSource == "demo_seed"
        }
        return false
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
                await session.business.refreshProfile()
                if session.isDemoAccount { await session.refreshDemoRun() }
                if canGeneratePortrait,
                   session.business.visualProfile?.portrait == nil {
                    showsPortraitConsent = true
                }
            } catch is CancellationError {
                isAnalyzing = false
                analysisErrorMessage = nil
                return
            } catch where isExplicitVisionCancellation(error) {
                isAnalyzing = false
                analysisErrorMessage = nil
                return
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
            await session.business.refreshProfile()
            if session.isDemoAccount { await session.refreshDemoRun() }
            if canGeneratePortrait,
               session.business.visualProfile?.portrait == nil {
                showsPortraitConsent = true
            }
        } catch is CancellationError {
            isAnalyzing = false
            analysisErrorMessage = nil
            return
        } catch where isExplicitVisionCancellation(error) {
            isAnalyzing = false
            analysisErrorMessage = nil
            return
        } catch {
            analysisErrorMessage = visionFailureMessage(error, fallbackStage: failureStage)
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
