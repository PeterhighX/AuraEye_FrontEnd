import Photos
import PhotosUI
import SwiftUI
import UIKit

struct OfficialGalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: OfficialGalleryViewModel
    @State private var selectionTask: Task<Void, Never>?
    @State private var showsLimitedLibraryManager = false

    let onSelection: (VisionImageInput) async -> Void

    init(
        features: AccountFeatures,
        onSelection: @escaping (VisionImageInput) async -> Void
    ) {
        _viewModel = State(initialValue: OfficialGalleryViewModel(features: features))
        self.onSelection = onSelection
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("选择照片")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { dismiss() }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    if !viewModel.photos.isEmpty { selectionBar }
                }
        }
        .task { await viewModel.load() }
        .onDisappear {
            selectionTask?.cancel()
            selectionTask = nil
        }
        .background(
            LimitedLibraryManagementPresenter(isPresented: $showsLimitedLibraryManager)
                .frame(width: 0, height: 0)
        )
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .idle, .loading:
            ProgressView("正在加载照片…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            ContentUnavailableView(
                "没有可用照片",
                systemImage: "photo.on.rectangle.angled",
                description: Text("请在系统照片权限中选择允许 AuraEye 访问的图片。")
            )
        case .failed(let message):
            ContentUnavailableView {
                Label("无法打开相册", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("重新加载") { Task { await viewModel.load() } }
            }
        case .loaded:
            ScrollView {
                if shouldShowLimitedLibraryManagement {
                    Button("管理可访问照片") {
                        showsLimitedLibraryManager = true
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3),
                    spacing: 2
                ) {
                    ForEach(viewModel.photos) { photo in
                        GalleryPhotoCell(
                            photo: photo,
                            isSelected: viewModel.selectedPhotoID == photo.id
                        ) {
                            viewModel.select(photo)
                        }
                    }
                }
                .padding(.top, 12)
            }
        }
    }

    private var selectionBar: some View {
        VStack(spacing: 8) {
            if let message = viewModel.selectionErrorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                if viewModel.isLoadingSelection {
                    Button("取消加载") { selectionTask?.cancel() }
                        .buttonStyle(.bordered)
                }
                Button(viewModel.isLoadingSelection ? "正在读取原图…" : "使用照片") {
                    submitSelection()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.selectedPhotoID == nil || viewModel.isLoadingSelection)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var shouldShowLimitedLibraryManagement: Bool {
        viewModel.galleryMode == .authorizedLibrary
            && PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited
    }

    private func submitSelection() {
        selectionTask?.cancel()
        selectionTask = Task {
            guard let input = await viewModel.loadSelectedPhoto(), !Task.isCancelled else { return }
            dismiss()
            await onSelection(input)
        }
    }
}

private struct GalleryPhotoCell: View {
    let photo: SelectedPhoto
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GeometryReader { proxy in
                Image(uiImage: photo.preview)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.width)
                    .clipped()
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(isSelected ? Color.accentColor : .white)
                            .shadow(color: .black.opacity(0.35), radius: 2)
                            .padding(7)
                    }
                    .overlay {
                        if isSelected {
                            Rectangle().stroke(Color.accentColor, lineWidth: 3)
                        }
                    }
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("照片")
        .accessibilityValue(isSelected ? "已选择" : "未选择")
    }
}

private struct LimitedLibraryManagementPresenter: UIViewControllerRepresentable {
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {
        guard isPresented, controller.presentedViewController == nil else { return }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: controller)
        DispatchQueue.main.async { isPresented = false }
    }
}

struct OfficialGalleryContainer: View {
    let onSelection: (VisionImageInput) async -> Void

    var body: some View {
        if let features = SessionManager.shared.context?.features {
            OfficialGalleryView(features: features, onSelection: onSelection)
        } else {
            ContentUnavailableView("登录状态已失效", systemImage: "person.crop.circle.badge.exclamationmark")
        }
    }
}
