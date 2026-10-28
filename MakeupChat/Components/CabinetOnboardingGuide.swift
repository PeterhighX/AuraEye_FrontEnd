import SwiftUI

enum CabinetGuideTarget: Hashable {
    case addCard(CosmeticCategory)
    case sectionHeader(CosmeticCategory)
}

enum CabinetGuideStep {
    case addProduct
    case categories

    var message: String {
        switch self {
        case .addProduct: "点击+号添加化妆品照片识别并继续上妆"
        case .categories: "添加完全部三类化妆品后继续"
        }
    }

    func targets(for category: CosmeticCategory) -> [CabinetGuideTarget] {
        switch self {
        case .addProduct: [.addCard(category)]
        case .categories: [.sectionHeader(.eyeliner), .sectionHeader(.brush)]
        }
    }
}

struct CabinetGuideAnchorKey: PreferenceKey {
    static var defaultValue: [CabinetGuideTarget: Anchor<CGRect>] { [:] }

    static func reduce(
        value: inout [CabinetGuideTarget: Anchor<CGRect>],
        nextValue: () -> [CabinetGuideTarget: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

/// Cutouts follow the actual card/header bounds as the cabinet scrolls.
struct CabinetGuideOverlay: View {
    let step: CabinetGuideStep
    let highlights: [CGRect]
    let onContinue: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let focus = highlights.reduce(CGRect.null) { $0.union($1) }
            let showsBelow = focus.isNull || focus.midY < geometry.size.height / 2

            ZStack {
                Canvas { context, size in
                    context.fill(
                        Path(CGRect(origin: .zero, size: size)),
                        with: .color(.black.opacity(0.65))
                    )
                    context.blendMode = .destinationOut
                    for rect in highlights {
                        context.fill(
                            Path(roundedRect: rect.insetBy(dx: -4, dy: -4), cornerRadius: 18),
                            with: .color(.black)
                        )
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {}
                .accessibilityHidden(true)

                VStack(spacing: 0) {
                    if showsBelow {
                        Color.clear.frame(height: focus.isNull ? geometry.size.height / 3 : max(0, focus.maxY + 16))
                    } else {
                        Spacer(minLength: 16)
                    }

                    callout
                        .frame(maxWidth: 300)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)

                    if showsBelow {
                        Spacer(minLength: 16)
                    } else {
                        Color.clear.frame(height: max(0, geometry.size.height - focus.minY + 16))
                    }
                }
            }
        }
    }

    private var callout: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(step.message)
                .font(.subheadline)
                .foregroundStyle(AppTheme.ColorToken.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Button("继续", action: onContinue)
                .font(AppTheme.Typography.buttonLabel)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(AppTheme.ColorToken.buttonPrimary, in: Capsule())
                .buttonStyle(.plain)
        }
        .padding(18)
        .background(.white, in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card))
        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
        .accessibilityElement(children: .contain)
    }
}
