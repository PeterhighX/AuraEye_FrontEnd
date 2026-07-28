import SwiftUI

/// 从 SQLite 相对路径 `media/...` 或 Asset 名加载图片
struct LocalImageView: View {
    let storedPath: String?
    var assetName: String?
    var systemImage: String = "photo"
    var contentMode: ContentMode = .fill

    var body: some View {
        Group {
            if let uiImage = LocalMediaStore.loadImage(fromStoredPath: storedPath) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if let assetName {
                Image(assetName)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(AppTheme.ColorToken.textSecondary)
                    .symbolRenderingMode(.hierarchical)
            }
        }
    }
}
