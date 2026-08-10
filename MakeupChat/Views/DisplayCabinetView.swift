import SwiftUI
import UIKit

enum CabinetPresentationMode: Equatable {
    case mainTab
    case onboarding
}

struct DisplayCabinetView: View {
    @Bindable var session: AppSession
    var presentationMode: CabinetPresentationMode = .mainTab
    var onBack: (() -> Void)?
    @State private var viewModel = DisplayCabinetViewModel()
    @State private var showCamera = false
    @State private var pendingCategory: CosmeticCategory?
    @State private var showImageSourcePicker = false
    @State private var showPhotoLibrary = false
    @State private var showTopAddPrompt = false
    @State private var imageSource: UIImagePickerController.SourceType = .camera
    @State private var successMessage: String?
    @State private var guideHandPressed = false

    var body: some View {
        VStack(spacing: 0) {
            if presentationMode == .onboarding {
                onboardingBackHeader
            }

            if presentationMode == .mainTab {
                cabinetHeader
                    .padding(.top, 8)
            }

            ScrollView {
                VStack(spacing: 32) {
                    ForEach(visibleSections) { section in
                        cabinetSection(section)
                    }
                }
                .padding(.top, presentationMode == .onboarding ? 16 : 32)
                .padding(.bottom, 100)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(presentationMode == .onboarding ? .hidden : .automatic, for: .tabBar)
        .simultaneousGesture(
            DragGesture(minimumDistance: 28)
                .onEnded { value in
                    guard presentationMode == .onboarding else { return }
                    let isHorizontal = abs(value.translation.width) > abs(value.translation.height)
                    if isHorizontal,
                       value.translation.width < -85,
                       value.predictedEndTranslation.width < -120 {
                        onBack?()
                    }
                }
        )
        .onAppear {
            viewModel.reload()
            showPendingSuccessFeedback()
            startAddGuideAnimation()
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPickerView(
                onImageCaptured: { image in
                    let targetCategory = pendingCategory
                    Task {
                        await viewModel.recognizeProduct(
                            image: image,
                            categoryHint: targetCategory
                        )
                    }
                },
                sourceType: imageSource,
                cameraDevice: .rear
            )
        }
        .fullScreenCover(isPresented: $showPhotoLibrary) {
            OfficialGalleryContainer { input in
                await viewModel.recognizeProduct(
                    input: input,
                    categoryHint: pendingCategory
                )
            }
        }
        .alert("前往添加化妆品", isPresented: $showTopAddPrompt) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(topAddGuidance)
        }
        .alert(
            "未识别到产品类型",
            isPresented: Binding(
                get: { viewModel.recognitionErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.dismissRecognitionError()
                    }
                }
            )
        ) {
            Button("重新识别", role: .cancel) {
                viewModel.dismissRecognitionError()
            }
        } message: {
            Text(viewModel.recognitionErrorMessage ?? "")
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
            } else if viewModel.isRecognizing {
                ZStack {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    ProgressView("识别中…")
                        .padding(20)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card))
                }
            }
        }
        .overlay(alignment: .top) {
            if let successMessage {
                Label(successMessage, systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.green, in: Capsule())
                    .shadow(color: .black.opacity(0.16), radius: 8, y: 4)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private func productConfirmation(_ product: CosmeticsRecognitionResult) -> some View {
        ZStack {
            Color.black.opacity(0.58)
                .ignoresSafeArea()
                .transition(.opacity)

            VStack(spacing: 16) {
                Text(product.displayName)
                    .font(.system(size: 20, weight: .regular, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .leading)

                LocalImageView(storedPath: product.previewPath)
                    .frame(width: 160, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Text(product.category)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color(.secondarySystemFill), in: Capsule())

                VStack(spacing: 10) {
                    Button {
                        viewModel.rejectPendingProduct()
                    } label: {
                        Text("拒绝")
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(.systemGray5), in: Capsule())
                    }

                    Button {
                        if viewModel.confirmPendingProduct() {
                            session.markCosmeticsAdded()
                            session.reportCosmeticAdded(category: product.category)
                            showPendingSuccessFeedback()
                        }
                    } label: {
                        Text("添加")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(red: 104 / 255, green: 106 / 255, blue: 219 / 255), in: Capsule())
                    }
                }
            }
            .padding(24)
            .frame(width: 300)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32))
            .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
            .transition(.scale(scale: 0.94).combined(with: .opacity))
        }
        .animation(.easeOut(duration: 0.2), value: viewModel.pendingProduct != nil)
    }

    private var cabinetHeader: some View {
        UserIdentityHeaderView(user: viewModel.user) {
            Button {
                showTopAddPrompt = true
            } label: {
                Image("CabinetAdd")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("添加化妆品")
        }
    }

    /// 新手扫描流程只展示任务要求的眼影、眼线和毛刷三类内容。
    private var visibleSections: [CabinetSection] {
        guard presentationMode == .onboarding else {
            return viewModel.sections
        }

        let requiredCategories: Set<CosmeticCategory> = [.eyeshadow, .eyeliner, .brush]
        return viewModel.sections.filter { requiredCategories.contains($0.category) }
    }

    private var onboardingBackHeader: some View {
        HStack(spacing: 8) {
            Button {
                onBack?()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color(red: 0.22, green: 0.22, blue: 0.22))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("返回步骤页面")

            Text("返回步骤")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color(red: 0.22, green: 0.22, blue: 0.22))

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }

    private func cabinetSection(_ section: CabinetSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            CabinetSectionHeader(category: section.category)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: section.category == .eyeshadow ? 12 : 14) {
                    ForEach(section.items) { item in
                        CosmeticProductCard(item: item, category: section.category)
                    }

                    addProductButton(for: section.category)
                }
                .padding(.horizontal, 16)
            }
        }
    }

    @ViewBuilder
    private func addProductButton(for category: CosmeticCategory) -> some View {
        Button {
            pendingCategory = category
            presentImageSourcePicker()
        } label: {
            AddCosmeticCard(category: category)
                .overlay(alignment: .topTrailing) {
                    if category == highlightedCategory {
                        Image("AddGuideHand")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 52, height: 64)
                            .scaleEffect(guideHandPressed ? 0.88 : 1)
                            .offset(
                                x: 6,
                                y: guideHandPressed ? 24 : 13
                            )
                            .shadow(
                                color: Color(red: 1, green: 0.72, blue: 0.14).opacity(0.55),
                                radius: 8
                            )
                            .allowsHitTesting(false)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func presentImageSourcePicker() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            showImageSourcePicker = true
        }
    }

    private var highlightedCategory: CosmeticCategory? {
        if presentationMode == .onboarding {
            return CosmeticCategory.allCases.first {
                !session.onboardingCosmeticCategories.contains($0)
            }
        }
        return CosmeticCategory.allCases.first { category in
            viewModel.sections
                .first(where: { $0.category == category })?
                .items
                .isEmpty != false
        }
    }

    private var topAddGuidance: String {
        if let highlightedCategory {
            return "还需添加\(highlightedCategory.rawValue)。眼影、眼线和毛刷三类全部添加后，才会解锁妆容生成。"
        }
        return "眼影、眼线和毛刷均已添加，仍可继续补充其他产品。"
    }

    private func showPendingSuccessFeedback() {
        guard let message = session.consumeCosmeticSuccessMessage() else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            successMessage = message
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(.easeIn(duration: 0.2)) {
                successMessage = nil
            }
        }
    }

    private func startAddGuideAnimation() {
        guard highlightedCategory != nil else { return }
        guideHandPressed = false
        withAnimation(.easeInOut(duration: 0.62).repeatForever(autoreverses: true)) {
            guideHandPressed = true
        }
    }
}

#Preview {
    DisplayCabinetView(session: AppSession())
}
