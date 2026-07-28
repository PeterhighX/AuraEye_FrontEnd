import SwiftUI
import UIKit

struct DisplayCabinetView: View {
    @Bindable var session: AppSession
    @State private var viewModel = DisplayCabinetViewModel()
    @State private var showCamera = false
    @State private var pendingCategory: CosmeticCategory?
    @State private var showImageSourcePicker = false
    @State private var imageSource: UIImagePickerController.SourceType = .camera

    var body: some View {
        VStack(spacing: 0) {
            cabinetHeader
                .padding(.top, 8)

            ScrollView {
                VStack(spacing: 32) {
                    ForEach(viewModel.sections) { section in
                        cabinetSection(section)
                    }
                }
                .padding(.top, 32)
                .padding(.bottom, 100)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.reload() }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPickerView(
                onImageCaptured: { image in
                    Task {
                        await viewModel.recognizeProduct(
                            image: image,
                            categoryHint: pendingCategory
                        )
                    }
                },
                sourceType: imageSource,
                cameraDevice: .rear
            )
        }
        .confirmationDialog(
            "添加产品照片",
            isPresented: $showImageSourcePicker,
            titleVisibility: .visible
        ) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("拍照") {
                    imageSource = .camera
                    showCamera = true
                }
            }

            Button("从相册选择") {
                imageSource = .photoLibrary
                showCamera = true
            }

            Button("取消", role: .cancel) {}
        } message: {
            Text("可以拍摄商品，也可以选择已经下载到设备相册的图片。")
        }
        .overlay {
            if let product = viewModel.pendingProduct {
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
                pendingCategory = nil
                presentImageSourcePicker()
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

    private func cabinetSection(_ section: CabinetSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            CabinetSectionHeader(category: section.category)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: section.category == .eyeshadow ? 12 : 14) {
                    ForEach(section.items) { item in
                        CosmeticProductCard(item: item, category: section.category)
                    }

                    Button {
                        pendingCategory = section.category
                        presentImageSourcePicker()
                    } label: {
                        AddCosmeticCard()
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func presentImageSourcePicker() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            showImageSourcePicker = true
        }
    }
}

#Preview {
    DisplayCabinetView(session: AppSession())
}
