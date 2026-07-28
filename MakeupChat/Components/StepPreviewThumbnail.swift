import SwiftUI
import UIKit

/// 步骤卡片左侧预览：有扫描/生成图则显示图片，否则显示步骤预览占位
struct StepPreviewThumbnail: View {
    let step: OnboardingStep

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.95, green: 0.95, blue: 0.95).opacity(0.25))

            previewContent
        }
        .frame(width: 76, height: 99)
        .offset(y: -6)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var previewContent: some View {
        if let image = resolvedPreviewImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 76, height: 99)
                .clipped()
        } else if let assetName = step.previewAsset, UIImage(named: assetName) != nil {
            Image(assetName)
                .resizable()
                .scaledToFill()
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
