import SwiftUI
import UIKit

/// 步骤卡片左侧预览：有扫描/生成图则显示图片，否则显示步骤预览占位
struct StepPreviewThumbnail: View {
    let step: OnboardingStep

    var body: some View {
        ZStack {
            previewContent
        }
        .frame(width: 76, height: 99)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var previewContent: some View {
        if step.stepKey != .userProfile,
           let assetName = step.previewAsset,
           UIImage(named: assetName) != nil {
            // Step 2 / Step 3 使用设计稿规定的固定 SVG，
            // 扫描完成后的商品图片仅写入陈列柜，不替换步骤卡片。
            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 76, height: 99)
                .clipped()
        } else if let image = resolvedPreviewImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 76, height: 99)
                .clipped()
        } else if let assetName = step.previewAsset, UIImage(named: assetName) != nil {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 76, height: 99)
                .clipped()
        } else {
            OnboardingStepPreviewPlaceholder(stepKey: step.stepKey)
                .frame(width: 76, height: 99)
        }
    }

    private var resolvedPreviewImage: UIImage? {
        guard let path = step.previewPath else { return nil }
        return LocalMediaStore.loadImage(fromStoredPath: path)
    }
}
