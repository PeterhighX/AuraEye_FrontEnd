import SwiftUI

struct MakeupPreviewView: View {
    @Bindable var session: AppSession
    @Binding var path: NavigationPath
    @Environment(\.dismiss) private var dismiss
    @State private var expandedStep: Int?
    @State private var selectedLookIndex = 0

    private let previewSteps: [(String, Color)] = [
        ("打底铺色", Color(red: 253 / 255, green: 235 / 255, blue: 235 / 255)),
        ("修容&阴影", Color(red: 1.0, green: 225 / 255, blue: 216 / 255)),
        ("眼睑下至", Color(red: 1.0, green: 193 / 255, blue: 174 / 255)),
        ("卧蚕", Color(red: 1.0, green: 154 / 255, blue: 124 / 255)),
        ("打底铺色", Color(red: 231 / 255, green: 108 / 255, blue: 69 / 255))
    ]

    private let recommendedLooks: [HomeRecommendedLook] = [
        HomeRecommendedLook(
            id: "clear_sweet",
            title: "清透甜美",
            tag: "少女感",
            imageAssetName: "HomeLookClear",
            swatchHexes: ["#C87A72", "#CE8C80", "#DCADA0"]
        ),
        HomeRecommendedLook(
            id: "chinese_warm",
            title: "中式温婉",
            tag: "东方韵味",
            imageAssetName: "HomeLookWarm",
            swatchHexes: ["#C15C40", "#C26947", "#EEAC9B"]
        ),
        HomeRecommendedLook(
            id: "hong_kong",
            title: "气质港风",
            tag: "复古范",
            imageAssetName: "HomeLookHongKong",
            swatchHexes: ["#9E3819", "#D16234", "#E7936A"]
        )
    ]

    var body: some View {
        ZStack {
            HomeBackgroundView()

            VStack(spacing: 0) {
                MakeupFlowHeaderView(title: "妆容预览", usesPreviewAssets: true) {
                    dismiss()
                }
                .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 24) {
                        if expandedStep == nil {
                            WeatherSummaryCard(
                                aiMessage: "今日天气多云，气温26℃，紫外线指数偏弱，可以放心大胆的出门哦！"
                            )
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        TipBarView(
                            tips: [expandedStep == nil
                                ? "眼神记得微微向下看着镜子来画哦，这样眼皮完全舒展开会让铺色更均匀。"
                                : "低调的色彩能完美衬托五官的质感"]
                        )

                        recommendedLookCard

                        VStack(spacing: -64) {
                            ForEach(Array(previewSteps.enumerated()), id: \.offset) { offset, step in
                                stepCard(
                                    index: offset + 1,
                                    title: step.0,
                                    color: step.1,
                                    isLast: offset == previewSteps.count - 1
                                )
                                .frame(height: expandedStep == offset ? 273 : (offset == previewSteps.count - 1 ? 87 : 120))
                                .zIndex(expandedStep == offset ? 10 : Double(offset))
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.46, dampingFraction: 0.82)) {
                                        expandedStep = expandedStep == offset ? nil : offset
                                    }
                                }
                            }
                        }
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
        .accessibilityAction(.escape) { expandedStep = nil }
    }

    private var recommendedLookCard: some View {
        let look = recommendedLooks[selectedLookIndex]

        return HStack(spacing: 12) {
            Image(look.imageAssetName)
                .resizable()
                .scaledToFill()
                .frame(width: 120, height: 120)
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
                            selectedLookIndex = (selectedLookIndex + 1) % recommendedLooks.count
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

                Text(look.id == "clear_sweet"
                    ? "适合日常出行，妆容简单，5分钟画完"
                    : look.id == "chinese_warm"
                        ? "适合通勤约会，柔和温婉，8分钟画完"
                        : "适合聚会拍照，复古利落，10分钟画完")
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

    private func stepCard(index: Int, title: String, color: Color, isLast: Bool = false) -> some View {
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
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card))
        .shadow(color: Color.black.opacity(0.09), radius: 2, y: 2)
        .overlay(alignment: .bottomLeading) {
            if expandedStep == index - 1 {
                Text(
                    index == 1
                        ? "• 咱们先保持眼部干燥，拿一把【大号铺色刷】沾取【哑光燕麦浅米色】，在整个上眼皮大面积铺色打底。手法一定要轻，少量多次地【叠加】，把眼皮上的暗沉和油脂都盖住。"
                        : "• 点击进入卡片式教学后，闪闪会根据当前步骤提供更详细的操作讲解。"
                )
                    .font(.system(size: 16, weight: .light))
                    .lineSpacing(5)
                    .foregroundStyle(index >= 4 ? .white : Color(red: 38 / 255, green: 38 / 255, blue: 38 / 255).opacity(0.75))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
                    .transition(.opacity)
            }
        }
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
