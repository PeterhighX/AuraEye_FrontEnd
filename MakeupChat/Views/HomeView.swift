import SwiftUI
import UIKit

/// Figma 20:607 — 首页
struct HomeView: View {
    @Bindable var session: AppSession
    @Binding var path: NavigationPath
    @Binding var selectedTab: Int
    @State private var viewModel = HomeViewModel()
    @State private var profileSetupViewModel = UserProfileSetupViewModel()
    @State private var showProfileImageSourcePicker = false
    @State private var showProfileImagePicker = false
    @State private var showProfilePhotoLibrary = false
    @State private var profileImageSource: UIImagePickerController.SourceType = .camera
    @State private var logoRotation = 0.0
    @State private var analysisTextPulse = false
    @State private var isAIEntryHovered = false
    @State private var isAIEntryPressed = false
    @State private var showsAIChat = false
    @State private var pageTransitionProgress: CGFloat = 0
    @State private var aiChatViewModel: ChatViewModel?
    @State private var chatConfigurationError: String?
    @State private var isClosingAIChat = false
    @StateObject private var weatherProvider = LiveWeatherProvider()

    private let recommendedLooks = MakeupLookCatalog.plans.map(\.look)

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                homeForeground
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .offset(x: pageTransitionProgress * proxy.size.width)
                    .allowsHitTesting(!showsAIChat)

                if showsAIChat, let aiChatViewModel {
                    ChatConversationView(
                        viewModel: aiChatViewModel,
                        layoutMode: .full,
                        onBack: { closeAIChat() }
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .offset(x: (pageTransitionProgress - 1) * proxy.size.width)
                    .zIndex(200)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 28)
                            .onEnded { value in
                                let isHorizontal = abs(value.translation.width) > abs(value.translation.height)
                                if isHorizontal,
                                   value.translation.width < -85,
                                   value.predictedEndTranslation.width < -120 {
                                    closeAIChat()
                                }
                            }
                    )
                }
            }
        }
        .appDynamicBackground()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(showsAIChat ? .hidden : .automatic, for: .tabBar)
        .onAppear {
            viewModel.reload()
            presentRequestedProfileCaptureIfNeeded()
        }
        .task {
            while !Task.isCancelled {
                weatherProvider.start()
                do {
                    try await Task.sleep(for: .seconds(30 * 60))
                } catch {
                    break
                }
            }
        }
        .onChange(of: session.shouldRequestProfileCapture) { _, requested in
            if requested {
                presentRequestedProfileCaptureIfNeeded()
            }
        }
        .alert("对话服务不可用", isPresented: Binding(
            get: { chatConfigurationError != nil },
            set: { if !$0 { chatConfigurationError = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(chatConfigurationError ?? "")
        }
        .fullScreenCover(isPresented: $showProfileImagePicker) {
            CameraPickerView(
                onImageCaptured: analyzeProfileImage,
                sourceType: profileImageSource,
                cameraDevice: .front
            )
        }
        .fullScreenCover(isPresented: $showProfilePhotoLibrary) {
            OfficialGalleryContainer(onSelection: analyzeProfileInput)
        }
        .alert(
            "分析未完成",
            isPresented: Binding(
                get: { profileSetupViewModel.errorMessage != nil },
                set: { if !$0 { profileSetupViewModel.clearError() } }
            )
        ) {
            Button("重新选择") {
                showProfileImageSourcePicker = true
            }
        } message: {
            Text(profileSetupViewModel.errorMessage ?? "")
        }
        .overlay {
            if showProfileImageSourcePicker {
                MediaSourceDialog(
                    showsCamera: !usesFixedDemoGallery,
                    onCamera: {
                        profileImageSource = .camera
                        showProfileImageSourcePicker = false
                        showProfileImagePicker = true
                    },
                    onLibrary: {
                        showProfileImageSourcePicker = false
                        showProfilePhotoLibrary = true
                    },
                    onCancel: { showProfileImageSourcePicker = false }
                )
            }
        }
    }

    private var usesFixedDemoGallery: Bool {
        SessionManager.shared.context?.features.galleryMode == .fixedDemo
    }

    private var homeForeground: some View {
        ZStack {
            VStack(spacing: 0) {
                homeHeader
                    .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 32) {
                        growthProgress
                        teachingSection
                        TipBarView()
                        recommendedSection
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 100)
                }
            }

            VStack {
                HStack {
                    Image("HomeAIFloating")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 70, height: 44)
                        // 默认只露出原设计右侧的圆形图标；悬停/按压时向右展开。
                        .offset(x: isAIEntryExpanded ? 0 : -26)
                    .frame(width: 70, height: 44, alignment: .leading)
                    .clipped()
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                            isAIEntryHovered = hovering
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                                    isAIEntryPressed = true
                                }
                            }
                            .onEnded { _ in
                                withAnimation(.easeOut(duration: 0.16)) {
                                    isAIEntryPressed = false
                                }
                                openAIChat()
                            }
                    )
                    .accessibilityLabel("打开 AI 妆容助手")

                    Spacer()
                }
                .padding(.top, 96)
                Spacer()
            }

            if profileSetupViewModel.isAnalyzing {
                profileAnalysisOverlay
            }
        }
    }

    private var isAIEntryExpanded: Bool {
        isAIEntryHovered || isAIEntryPressed
    }

    private func openAIChat() {
        guard !showsAIChat else { return }
        do {
            aiChatViewModel = try ChatCompositionRoot.makeViewModel()
        } catch {
            chatConfigurationError = error.localizedDescription
            return
        }
        isClosingAIChat = false
        pageTransitionProgress = 0
        showsAIChat = true
        session.isAIChatPresented = true

        // 背景不参与动画；两个前景容器像相邻卡片一样整体切换。
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.44, dampingFraction: 0.9)) {
                pageTransitionProgress = 1
            }
        }
    }

    private func closeAIChat(nextRoute: AppRoute? = nil) {
        guard showsAIChat, !isClosingAIChat else { return }
        isClosingAIChat = true

        // 负一屏向左退出、首页从右侧回到原位，Shader 背景保持固定。
        withAnimation(.easeInOut(duration: 0.3)) {
            pageTransitionProgress = 0
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            showsAIChat = false
            session.isAIChatPresented = false
            isClosingAIChat = false
            if let nextRoute {
                path.append(nextRoute)
            }
        }
    }

    // MARK: - Header

    private var homeHeader: some View {
        UserIdentityHeaderView(user: viewModel.user) {
            Button(action: { /* TODO: 打开搜索 */ }) {
                Image("HomeSearch")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("搜索")
        }
    }

    // MARK: - Growth

    private var growthProgress: some View {
        HStack {
            Spacer()
            VStack(spacing: 5) {
                HStack(alignment: .center) {
                    Text("成长进度")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .tracking(0)
                        .foregroundStyle(.white)
                    Spacer()
                    Text("LV.04")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .tracking(0)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color(red: 247 / 255, green: 119 / 255, blue: 83 / 255))
                        .clipShape(Capsule())
                }
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.6)).frame(height: 6)
                    Capsule()
                        .fill(Color(red: 1, green: 139 / 255, blue: 104 / 255))
                        .frame(width: 23, height: 6)
                }
                .frame(width: 165)
            }
            .frame(width: 165)
        }
        .padding(.trailing, 16)
    }

    // MARK: - Teaching + Quick Actions

    private var teachingSection: some View {
        VStack(spacing: 12) {
            HomeTeachingCard(weather: weatherProvider.snapshot) {
                path.append(session.routeForQuickStart())
            }

            HStack(spacing: 8) {
                quickActionButton(
                    title: "化妆品识别",
                    color: Color(red: 225 / 255, green: 224 / 255, blue: 1),
                    icon: "camera.fill"
                ) {
                    selectedTab = AppTab.cabinet.rawValue
                }

                quickActionButton(
                    title: "用户档案",
                    color: Color(red: 1, green: 181 / 255, blue: 159 / 255),
                    icon: "person.fill"
                ) {
                    if let profileRoute = session.routeForUserProfile() {
                        path.append(profileRoute)
                    } else {
                        beginProfileCapture()
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var profileAnalysisOverlay: some View {
        ZStack {
            Color.white.opacity(0.94)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image("PracticeToolIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
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
                    .scaleEffect(analysisTextPulse ? 1.015 : 0.995)
                    .offset(y: analysisTextPulse ? -1 : 1)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                            analysisTextPulse = true
                        }
                    }
            }
        }
        .transition(.opacity)
    }

    private func analyzeProfileImage(_ image: UIImage) {
        Task {
            let succeeded = await profileSetupViewModel.analyze(image, session: session)
            guard succeeded else { return }
            path.append(AppRoute.userProfile)
        }
    }

    private func analyzeProfileInput(_ input: VisionImageInput) async {
        let succeeded = await profileSetupViewModel.analyze(input, session: session)
        guard succeeded else { return }
        path.append(AppRoute.userProfile)
    }

    private func presentRequestedProfileCaptureIfNeeded() {
        guard session.shouldRequestProfileCapture else { return }
        session.consumeProfileCaptureRequest()
        beginProfileCapture()
    }

    private func beginProfileCapture() {
        showProfileImageSourcePicker = true
    }

    private func quickActionButton(
        title: String,
        color: Color,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .frame(width: 28, height: 28)
                Text(title)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .tracking(1)
            }
            .foregroundStyle(Color(red: 38 / 255, green: 38 / 255, blue: 38 / 255))
            .frame(maxWidth: .infinity)
            .frame(height: 57)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: Color.black.opacity(0.09), radius: 2, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recommended

    private var recommendedSection: some View {
        VStack(spacing: 24) {
            HStack {
                Text("推荐眼妆")
                    .font(.system(size: 20, weight: .regular, design: .rounded))
                    .tracking(0)
                    .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.2))
                Spacer()
                Image(systemName: "chevron.right.2")
                    .font(.system(size: 20, weight: .regular))
                    .frame(width: 22, height: 22)
                    .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.2))
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(recommendedLooks) { look in
                        HomeRecommendedLookCard(look: look)
                    }
                }
                .padding(.horizontal, 12)
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }
}

#Preview {
    NavigationStack {
        HomeView(session: AppSession(), path: .constant(NavigationPath()), selectedTab: .constant(0))
    }
}
