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
    @State private var profileImageSource: UIImagePickerController.SourceType = .camera
    @State private var logoRotation = 0.0
    @State private var analysisTextPulse = false

    private let recommendedLooks: [HomeRecommendedLook] = [
        HomeRecommendedLook(
            id: "clear_sweet",
            title: "清透甜美",
            tag: "少女感",
            imageAssetName: "HomeLookClear",
            swatchHexes: ["#C87A72", "#CE8C80", "#DCADA0"]
        ),
        HomeRecommendedLook(
            id: "chinese_warm",
            title: "中式温婉",
            tag: "东方韵味",
            imageAssetName: "HomeLookWarm",
            swatchHexes: ["#C15C40", "#C26947", "#EEAC9B"]
        ),
        HomeRecommendedLook(
            id: "hong_kong",
            title: "气质港风",
            tag: "复古范",
            imageAssetName: "HomeLookHongKong",
            swatchHexes: ["#9E3819", "#D16234", "#E7936A"]
        )
    ]

    var body: some View {
        ZStack {
            HomeBackgroundView()

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

            if profileSetupViewModel.isAnalyzing {
                profileAnalysisOverlay
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            viewModel.reload()
            presentRequestedProfileCaptureIfNeeded()
        }
        .onChange(of: session.shouldRequestProfileCapture) { _, requested in
            if requested {
                presentRequestedProfileCaptureIfNeeded()
            }
        }
        .confirmationDialog(
            "创建用户档案",
            isPresented: $showProfileImageSourcePicker,
            titleVisibility: .visible
        ) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("拍摄正脸照片") {
                    profileImageSource = .camera
                    showProfileImagePicker = true
                }
            }

            Button("从相册选择") {
                profileImageSource = .photoLibrary
                showProfileImagePicker = true
            }

            Button("取消", role: .cancel) {}
        } message: {
            Text("拍摄清晰正脸照片，或选择设备上已经下载的照片。")
        }
        .fullScreenCover(isPresented: $showProfileImagePicker) {
            CameraPickerView(
                onImageCaptured: analyzeProfileImage,
                sourceType: profileImageSource,
                cameraDevice: .front
            )
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
        HStack(alignment: .bottom) {
            Button {
                path.append(AppRoute.aiChat)
            } label: {
                Image("HomeAIEntry")
                    .resizable()
                    .scaledToFit()
                .frame(width: 70, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("打开 AI 妆容助手")

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                HStack {
                    Text("成长进度")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .tracking(0)
                        .foregroundStyle(.white)
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
        }
        .padding(.trailing, 16)
    }

    // MARK: - Teaching + Quick Actions

    private var teachingSection: some View {
        VStack(spacing: 12) {
            HomeTeachingCard {
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
                    if session.hasScannedFace {
                        path.append(AppRoute.userProfile)
                    } else {
                        showProfileImageSourcePicker = true
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
                Image("AuraAyeLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 132, height: 132)
                    .frame(width: 132, height: 94, alignment: .top)
                    .clipped()
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

    private func presentRequestedProfileCaptureIfNeeded() {
        guard session.shouldRequestProfileCapture else { return }
        session.consumeProfileCaptureRequest()
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

            if session.hasScannedFace {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(recommendedLooks) { look in
                            HomeRecommendedLookCard(look: look)
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                Text("建立用户档案后，为你生成专属眼妆推荐")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 96)
                    .background(
                        Color(red: 243 / 255, green: 240 / 255, blue: 239 / 255).opacity(0.55),
                        in: RoundedRectangle(cornerRadius: 18)
                    )
                    .padding(.horizontal, 16)
            }
        }
        .animation(.easeOut(duration: 0.25), value: session.hasScannedFace)
    }
}

#Preview {
    NavigationStack {
        HomeView(session: AppSession(), path: .constant(NavigationPath()), selectedTab: .constant(0))
    }
}
