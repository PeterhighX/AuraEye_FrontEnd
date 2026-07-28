import UIKit

/// 妆容生成步骤的本地预览缩略图（占位，后台接入后可替换为真实渲染图）
enum MakeupPreviewThumbnailRenderer {
    static func render(style: EyeStyle?) -> UIImage {
        let size = CGSize(width: 152, height: 198)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let top = UIColor(red: 1.0, green: 0.72, blue: 0.60, alpha: 1.0)
            let bottom = UIColor(red: 0.96, green: 0.55, blue: 0.48, alpha: 1.0)
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [top.cgColor, bottom.cgColor] as CFArray,
                locations: [0, 1]
            )!
            context.cgContext.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )

            let eyeRect = CGRect(x: 36, y: 58, width: 80, height: 52)
            context.cgContext.setFillColor(UIColor.white.withAlphaComponent(0.35).cgColor)
            context.cgContext.fillEllipse(in: eyeRect)

            let main = uiColor(hex: style?.eyeColorMain ?? "#C4A484")
            let sub = uiColor(hex: style?.eyeColorSub ?? "#8B7355")
            let swatchY = eyeRect.maxY + 18
            for (index, color) in [main, sub, UIColor.white.withAlphaComponent(0.8)].enumerated() {
                let x = 46 + CGFloat(index) * 22
                context.cgContext.setFillColor(color.cgColor)
                context.cgContext.fillEllipse(in: CGRect(x: x, y: swatchY, width: 16, height: 16))
            }

            let label = "预览"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.9)
            ]
            let textSize = label.size(withAttributes: attrs)
            label.draw(
                at: CGPoint(x: size.width - textSize.width - 12, y: size.height - textSize.height - 10),
                withAttributes: attrs
            )
        }
    }

    private static func uiColor(hex: String) -> UIColor {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitized.hasPrefix("#") { sanitized.removeFirst() }
        guard sanitized.count == 6, let value = UInt64(sanitized, radix: 16) else {
            return UIColor.gray
        }
        return UIColor(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}
