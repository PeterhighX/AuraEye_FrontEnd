import SwiftUI

struct MakeupPreviewView: View {
    @Bindable var session: AppSession
    @Binding var path: NavigationPath
    @Environment(\.dismiss) private var dismiss
    @State private var expandedStep: Int?
    @State private var selectedLookIndex = 0

    private let stepColors: [Color] = [
        Color(red: 253 / 255, green: 235 / 255, blue: 235 / 255),
        Color(red: 1.0, green: 225 / 255, blue: 216 / 255),
        Color(red: 1.0, green: 193 / 255, blue: 174 / 255),
        Color(red: 1.0, green: 154 / 255, blue: 124 / 255),
        Color(red: 231 / 255, green: 108 / 255, blue: 69 / 255)
    ]

    private var selectedPlan: MakeupLookPlan {
        MakeupLookCatalog.plans[selectedLookIndex]
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                MakeupFlowHeaderView(title: "妆容预览", usesPreviewAssets: true) {
                    dismiss()
                }
                .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 24) {
                        if expandedStep == nil {
                            Image("MakeupPreviewWeatherComposed")
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .accessibilityLabel("今日天气卡片")
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        TipBarView(
                            tips: [expandedStep == nil
                                ? "眼神记得微微向下看着镜子来画哦，这样眼皮完全舒展开会让铺色更均匀。"
                                : "低调的色彩能完美衬托五官的质感"]
                        )

                        recommendedLookCard
                            .id("look-card-\(selectedPlan.id)")

                        VStack(spacing: -64) {
                            ForEach(Array(selectedPlan.steps.enumerated()), id: \.element.id) { offset, step in
                                stepCard(
                                    index: offset + 1,
                                    title: step.title,
                                    instruction: step.instruction,
                                    color: stepColors[offset],
                                    isLast: offset == selectedPlan.steps.count - 1
                                )
                                .frame(height: expandedStep == offset ? 273 : 120)
                                // Keep every step in its original stack order. Later cards
                                // remain above earlier cards only where the stack overlaps,
                                // so an expanded card never covers the remaining steps.
                                .zIndex(Double(offset))
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.46, dampingFraction: 0.82)) {
                                        expandedStep = expandedStep == offset ? nil : offset
                                    }
                                }
                            }
                        }
                        // 三套妆容的步骤编号相同，使用方案 ID 强制刷新整组文案，
                        // 避免 SwiftUI 在切换时复用上一套 step 1...5 的内容。
                        .id("step-stack-\(selectedPlan.id)")
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, expandedStep == nil ? 24 : 0)
                    .padding(.bottom, 40)
                    .animation(.spring(response: 0.48, dampingFraction: 0.86), value: expandedStep)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            selectedLookIndex = MakeupLookCatalog.plans.firstIndex(where: { $0.id == session.selectedLookID }) ?? 0
        }
        .accessibilityAction(.escape) { expandedStep = nil }
    }

    private var recommendedLookCard: some View {
        let plan = selectedPlan
        let look = plan.look

        return HStack(spacing: 12) {
            Image(look.imageAssetName)
                .resizable()
                .scaledToFill()
                .frame(width: 120, height: 120)
                .scaleEffect(1.1)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.08), radius: 2)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(look.title)
                            .font(.system(size: 16, weight: .light))
                        Text(look.tag)
                            .font(.system(size: 11, weight: .light))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 2)
                            .background(Color(red: 1.0, green: 0.93, blue: 0.91))
                            .clipShape(Capsule())
                    }
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            selectedLookIndex = (selectedLookIndex + 1) % MakeupLookCatalog.plans.count
                            session.selectedLookID = MakeupLookCatalog.plans[selectedLookIndex].id
                            expandedStep = nil
                        }
                    } label: {
                        Image("PreviewSwitch")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("切换推荐妆容")
                }

                Text(plan.summary)
                    .font(.system(size: 12, weight: .light))
                    .lineSpacing(4)

                HStack {
                    HStack(spacing: 6) {
                        ForEach(look.swatchHexes, id: \.self) { hex in
                            Circle()
                                .fill(Color(previewHex: hex))
                                .frame(width: 28, height: 28)
                        }
                    }
                    Spacer()
                    Button {
                        session.selectedLookID = plan.id
                        session.markFirstUseCompleted()
                        path.append(AppRoute.makeupSteps)
                    } label: {
                        Text("开始上妆")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .tracking(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(red: 0.15, green: 0.15, blue: 0.15))
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.button))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .frame(height: 136)
        .background(Color.white.opacity(expandedStep == nil ? 0.55 : 0.65))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card))
        .shadow(color: Color.black.opacity(0.09), radius: 2, y: 2)
        .padding(.horizontal, 16)
    }

    private func stepCard(
        index: Int,
        title: String,
        instruction: String,
        color: Color,
        isLast: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: expandedStep == index - 1 ? 18 : 0) {
            HStack {
                HStack(spacing: 17) {
                    Text("step \(index)")
                        .font(.system(size: 20, weight: .semibold))
                    Text(title)
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                }
                .foregroundStyle(index >= 4 ? .white : Color(red: 0.15, green: 0.15, blue: 0.15).opacity(0.75))

                Spacer()

                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle()
                            .fill(index >= 4 ? Color.white : Color(red: 0.15, green: 0.15, blue: 0.15).opacity(0.3))
                            .frame(width: 4, height: 4)
                    }
                }
            }

            if expandedStep == index - 1 {
                styledMakeupInstruction(
                    instruction,
                    bullet: true,
                    highlightColor: index >= 4
                        ? .white
                        : AppTheme.ColorToken.accentCoral
                )
                    .font(.system(size: 16, weight: .light))
                    .lineSpacing(5)
                    .foregroundStyle(index >= 4 ? .white : Color(red: 38 / 255, green: 38 / 255, blue: 38 / 255).opacity(0.75))
                    .padding(.horizontal, 6)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card))
        .shadow(color: Color.black.opacity(0.09), radius: 2, y: 2)
    }
}

private extension Color {
    init(previewHex: String) {
        let value = UInt64(previewHex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

#Preview {
    NavigationStack {
        MakeupPreviewView(session: AppSession(), path: .constant(NavigationPath()))
    }
}
