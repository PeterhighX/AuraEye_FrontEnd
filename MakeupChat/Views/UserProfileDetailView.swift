import SwiftUI
import UIKit

@MainActor
struct UserProfileDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: AppSession
    @Binding var path: NavigationPath
    @State private var user: UserProfile?
    @State private var showsCamera = false
    @State private var showsPhotoLibrary = false
    @State private var showsSourcePicker = false
    @State private var imageSource: UIImagePickerController.SourceType = .camera
    @State private var isAnalyzing = false
    @State private var analysisErrorMessage: String?
    @State private var showsProfileMenu = false
    @State private var isGeneratingPortrait = false
    @State private var portraitRequestID: String?
    @State private var quickStartMessage: String?
    @State private var statusMessage: String?

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
                regenerateNarrative()
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
        }
        .onChange(of: session.business.visualProfile?.narrativeStatus) { _, status in
            switch status {
            case "pending", "running": showStatus("正在生成文字分析报告…")
            case "completed": showStatus("文字分析报告已更新")
            case "unavailable": showStatus("文字分析报告暂不可用")
            default: break
            }
        }
        .onChange(of: session.business.visualProfile?.portrait?.status) { _, status in
            if status != nil {
                showStatus(portraitStatus(session.business.visualProfile?.portrait))
            }
        }
        .overlay(alignment: .top) {
            if let statusMessage {
                HStack(spacing: 10) {
                    Image(systemName: AppTheme.Symbol.sparkle)
                        .symbolEffect(.pulse, options: .repeating)
                    Text(statusMessage)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(AppTheme.ColorToken.textPrimary)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                .padding(.horizontal, 24)
                .padding(.top, 56)
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityAddTraits(.updatesFrequently)
                .allowsHitTesting(false)
            }
        }
        .animation(AppTheme.Motion.quickSpring, value: statusMessage)
        .task(id: statusMessage) {
            guard statusMessage != nil else { return }
            do {
                try await Task.sleep(for: .seconds(2))
                statusMessage = nil
            } catch {
                // A new status restarts the two-second display interval.
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

            portraitImage(placeholderSize: 36)
                .frame(width: 36, height: 36)
                .clipShape(Circle())
        }
        .foregroundStyle(AppTheme.ColorToken.textPrimary)
        .padding(.horizontal, 16)
        .frame(height: 44)
    }

    // MARK: - Profile summary

    private var profileCard: some View {
        HStack(alignment: .center, spacing: 18) {
            portraitImage(placeholderSize: 72)
                .frame(width: 111, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .trailing, spacing: 10) {
                Text(session.authenticatedAccount?.displayName ?? "用户")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.ColorToken.textPrimary)
                    .lineLimit(1)

                Text(session.business.visualProfile?.eyeFeatureSummary
                    ?? (session.business.visualProfile == nil ? "眼型待分析" : "眼型特征待完善"))
                    .font(.system(size: 12, weight: .light))
                    .lineLimit(1)

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
            .padding(.vertical, 12)
        }
        .padding(.horizontal, 16)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.hero)
                .fill(Color(red: 1.0, green: 0.93, blue: 0.91).opacity(0.40))
        }
        .shadow(color: Color(red: 0.3, green: 0.3, blue: 0.3).opacity(0.09), radius: 4, y: 2)
        .padding(.horizontal, 16)
    }

    private func portraitImage(placeholderSize: CGFloat) -> some View {
        Group {
            if let data = session.business.avatarData,
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: placeholderSize, height: placeholderSize)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            Button(action: regenerateNarrative) {
                bottomButtonLabel("重新分析")
                    .foregroundStyle(AppTheme.ColorToken.textSecondary)
                    .background(Color.white.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.button))
            }
            .disabled(isAnalyzing)

            Button {
                if let route = session.routeForNewMakeup(styleID: nil) {
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

    private func showStatus(_ message: String) {
        statusMessage = message
    }

    private func regenerateNarrative() {
        // Keep this separate from face analysis until the text-only API is available.
        showStatus("文字报告重新生成暂不可用")
    }

    private func requestPortrait() async throws {
        guard let version = session.business.visualProfile?.profileVersion,
              canGeneratePortrait,
              !isGeneratingPortrait else { return }
        if session.business.visualProfile?.portrait?.status == "failed" {
            portraitRequestID = nil
        }
        let requestID = portraitRequestID ?? UUID().uuidString
        portraitRequestID = requestID
        isGeneratingPortrait = true
        defer { isGeneratingPortrait = false }
        showStatus("正在生成透明头像…")
        let ticket = try await BusinessDataService.shared.generatePortrait(
            requestID: requestID, profileVersion: version
        )
        for _ in 0..<200 {
            try Task.checkCancellation()
            await session.business.refreshProfile()
            if let error = session.business.profileError {
                throw NSError(domain: "ProfileGeneration", code: 1, userInfo: [NSLocalizedDescriptionKey: error])
            }
            guard let profile = session.business.visualProfile,
                  profile.profileVersion == version else { throw VisionAPIError.resultInvalid }
            if let portrait = profile.portrait {
                if portrait.status == "succeeded" {
                    guard portrait.hasAlpha else { throw VisionAPIError.resultInvalid }
                    if let data = session.business.avatarData, UIImage(data: data) != nil {
                        showStatus("透明头像已更新")
                        return
                    }
                }
                if portrait.status == "failed" {
                    throw NSError(domain: "ProfileGeneration", code: 2, userInfo: [
                        NSLocalizedDescriptionKey: portrait.error?.message ?? "透明头像生成失败，文字分析报告已保留。"
                    ])
                }
            }
            try await Task.sleep(for: .milliseconds(max(500, min(ticket.pollAfterMS, 10_000))))
        }
        throw VisionAPIError.jobTimedOut
    }

    private func waitForNarrative() async throws -> Bool {
        guard let version = session.business.visualProfile?.profileVersion else {
            throw VisionAPIError.resultInvalid
        }
        for _ in 0..<200 {
            try Task.checkCancellation()
            guard let profile = session.business.visualProfile,
                  profile.profileVersion == version else { throw VisionAPIError.resultInvalid }
            guard profile.narrativeStatus == "pending" || profile.narrativeStatus == "running" else {
                return profile.narrative != nil && profile.narrativeStatus != "unavailable"
            }
            try await Task.sleep(for: .milliseconds(1_500))
            await session.business.refreshProfile()
            if let error = session.business.profileError {
                throw NSError(domain: "ProfileGeneration", code: 1, userInfo: [NSLocalizedDescriptionKey: error])
            }
        }
        throw VisionAPIError.jobTimedOut
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
        Task {
            await generateVirtualAvatar(from: VisionImageInput(image: image))
        }
    }

    private func generateVirtualAvatar(from input: VisionImageInput) async {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        defer { isAnalyzing = false }
        guard var profile = try? userRepository.currentUser() else { return }
        analysisErrorMessage = nil
        showStatus("正在分析面部并生成文字报告…")
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
            user = profile
            failureStage = .processingResult
            await session.business.refreshProfile()
            if let error = session.business.profileError {
                throw NSError(domain: "ProfileGeneration", code: 1, userInfo: [NSLocalizedDescriptionKey: error])
            }
            if session.isDemoAccount { await session.refreshDemoRun() }
            portraitRequestID = nil
            if canGeneratePortrait {
                try await requestPortrait()
            }
            let hasNarrative = try await waitForNarrative()
            if !hasNarrative {
                showStatus("面部分析已完成，文字报告暂不可用")
            } else {
                showStatus(canGeneratePortrait ? "文字报告与透明头像已更新" : "文字报告已更新，当前照片暂不支持透明头像")
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
            showStatus("分析未完成，请稍后重试")
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
