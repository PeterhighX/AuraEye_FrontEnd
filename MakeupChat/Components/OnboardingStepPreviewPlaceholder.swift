import SwiftUI

/// 第一次使用三步卡片左侧预览占位 — 扫描前展示；有 `previewPath` 后由真实图替换
struct OnboardingStepPreviewPlaceholder: View {
    let stepKey: OnboardingStepKey

    var body: some View {
        ZStack {
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white.opacity(0.95))

                if stepKey == .makeupGenerate {
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(swatchColors[index])
                                .frame(width: 10, height: 10)
                        }
                    }
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Text("预览")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.12))
                .clipShape(Capsule())
                .padding(6)
        }
    }

    private var iconName: String {
        switch stepKey {
        case .userProfile: return "person.crop.rectangle"
        case .cosmetics: return "shippingbox.fill"
        case .makeupGenerate: return "eye.fill"
        }
    }

    private var gradientColors: [Color] {
        switch stepKey {
        case .userProfile:
            return [
                Color(red: 1.0, green: 0.78, blue: 0.72),
                Color(red: 0.98, green: 0.62, blue: 0.58)
            ]
        case .cosmetics:
            return [
                Color(red: 0.82, green: 0.82, blue: 1.0),
                Color(red: 0.68, green: 0.70, blue: 0.96)
            ]
        case .makeupGenerate:
            return [
                Color(red: 1.0, green: 0.72, blue: 0.60),
                Color(red: 0.96, green: 0.55, blue: 0.48)
            ]
        }
    }

    private var swatchColors: [Color] {
        [
            Color(red: 0.85, green: 0.72, blue: 0.65),
            Color(red: 0.77, green: 0.65, blue: 0.52),
            Color(red: 0.91, green: 0.77, blue: 0.72)
        ]
    }
}
