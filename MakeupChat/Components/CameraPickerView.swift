import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct CameraPickerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    let onImageCaptured: (UIImage) -> Void
    var sourceType: UIImagePickerController.SourceType = .camera
    var cameraDevice: UIImagePickerController.CameraDevice = .front

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        picker.mediaTypes = [UTType.image.identifier]

        if UIImagePickerController.isSourceTypeAvailable(sourceType) {
            picker.sourceType = sourceType
        } else if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            picker.sourceType = .photoLibrary
        }

        if picker.sourceType == .camera {
            if UIImagePickerController.isCameraDeviceAvailable(cameraDevice) {
                picker.cameraDevice = cameraDevice
            }
        }

        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraPickerView

        init(parent: CameraPickerView) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            }
            parent.dismiss()
        }
    }
}

/// 统一媒体来源弹窗。相机与相册仍由 iOS 官方控制器承载，
/// 这里只负责产品要求的居中布局和品牌色按钮。
struct MediaSourceDialog: View {
    let onCamera: () -> Void
    let onLibrary: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            VStack(spacing: 12) {
                Text("选择媒体来源")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(red: 51 / 255, green: 51 / 255, blue: 51 / 255))
                    .padding(.bottom, 4)

                sourceButton("拍照", action: onCamera)
                sourceButton("相册", action: onLibrary)

                Button("取消", action: onCancel)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(red: 51 / 255, green: 51 / 255, blue: 51 / 255))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .padding(20)
            .frame(width: 286)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26))
            .shadow(color: .black.opacity(0.16), radius: 24, y: 10)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
        .zIndex(100)
    }

    private func sourceButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(AppTheme.ColorToken.accentCoral, in: RoundedRectangle(cornerRadius: 16))
    }
}
