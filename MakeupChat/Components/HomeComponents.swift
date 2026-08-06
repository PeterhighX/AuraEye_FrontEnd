import SwiftUI

struct HomeRecommendedLook: Identifiable {
    let id: String
    let title: String
    let tag: String
    let imageAssetName: String
    /// 模型/后端后续直接返回的绝对 HEX 色值。
    let swatchHexes: [String]
}

struct HomeRecommendedLookCard: View {
    let look: HomeRecommendedLook

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Image(look.imageAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    // 源 SVG 自带 4pt 投影留白，放大后再裁切，避免预览出现边线。
                    .scaleEffect(1.1)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color.black.opacity(0.08), radius: 2)

                Text(look.title)
                    .font(.system(size: 14, weight: .light))
                    .tracking(1)
                    .foregroundStyle(Color(red: 38 / 255, green: 38 / 255, blue: 38 / 255))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
            }
            .padding(.bottom, 8)
            .frame(width: 120)
            .background(Color(red: 243 / 255, green: 240 / 255, blue: 239 / 255))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(look.tag)
                .font(.system(size: 11, weight: .light))
                .tracking(1)
                .padding(.horizontal, 12)
                .frame(height: 15)
                .background(Color(red: 243 / 255, green: 240 / 255, blue: 239 / 255))
                .clipShape(Capsule())

            HStack(spacing: 8) {
                ForEach(look.swatchHexes, id: \.self) { hex in
                    Circle()
                        .fill(Color(homeHex: hex))
                        .frame(width: 28, height: 28)
                        .accessibilityLabel("色值 \(hex)")
                }
            }
            .frame(height: 28)
        }
        .frame(width: 120)
    }
}

private extension Color {
    init(homeHex: String) {
        let value = UInt64(homeHex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

struct HomeTeachingCard: View {
    let weather: LiveWeatherSnapshot
    let onQuickStart: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(red: 1, green: 237 / 255, blue: 232 / 255).opacity(0.4))
                .shadow(color: Color.black.opacity(0.09), radius: 2, y: 2)
                .frame(height: 148)

            Image(systemName: weather.symbolName)
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 68))
                .frame(width: 120, height: 90)
                .padding(.leading, 18)
                .offset(y: -20)
                .contentTransition(.symbolEffect(.replace))

            VStack(alignment: .trailing, spacing: 4) {
                Text("上妆教学")
                    .font(.system(size: 20, weight: .semibold))
                    .tracking(0)
                    .foregroundStyle(Color(red: 38 / 255, green: 38 / 255, blue: 38 / 255))
                Text("跟随教程开启你的眼妆之路")
                    .font(.system(size: 14, weight: .thin))
                    .tracking(0)
                    .foregroundStyle(Color(red: 51 / 255, green: 51 / 255, blue: 51 / 255))
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 18)
            .padding(.top, 19)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 0) {
                    HStack(alignment: .top, spacing: 2) {
                        Text("\(weather.temperature)")
                            .font(.system(size: 24, weight: .semibold))
                            .tracking(0)
                            .foregroundStyle(Color(red: 85 / 255, green: 85 / 255, blue: 85 / 255))
                        VStack(alignment: .leading, spacing: 0) {
                            Text("℃")
                                .font(.system(size: 10, weight: .regular, design: .rounded))
                            Text(weather.conditionText)
                                .font(.system(size: 10, weight: .regular, design: .rounded))
                        }
                        .foregroundStyle(Color(red: 157 / 255, green: 157 / 255, blue: 157 / 255))
                    }

                    Spacer()

                    Text(weather.district)
                        .font(.system(size: 12, weight: .light))
                        .tracking(0)
                        .foregroundStyle(Color(red: 102 / 255, green: 102 / 255, blue: 102 / 255))
                        .padding(.horizontal, 6)
                        .frame(height: 18)
                        .background(
                            Color(red: 225 / 255, green: 244 / 255, blue: 253 / 255)
                                .opacity(0.45)
                        )
                        .clipShape(Capsule())
                }
                .frame(width: 140)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(
                            Color(red: 230 / 255, green: 242 / 255, blue: 248 / 255)
                                .opacity(0.45)
                        )
                        .frame(height: 9)
                    GeometryReader { proxy in
                        Capsule()
                            .fill(Color(red: 1, green: 139 / 255, blue: 104 / 255))
                            .frame(width: proxy.size.width * weather.uvProgress, height: 9)
                    }
                }
                .frame(width: 140)

                HStack {
                    HStack(spacing: 3) {
                        Image(systemName: "sun.max")
                            .font(.system(size: 12))
                        Text("紫外线指数")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                    }
                    Spacer()
                    Text(weather.uvDescription)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                }
                .foregroundStyle(Color(red: 102 / 255, green: 102 / 255, blue: 102 / 255))
                .frame(width: 140)
            }
            .padding(.leading, 18)
            .padding(.top, 78)

            Button(action: onQuickStart) {
                HStack(spacing: 12) {
                    Image(systemName: "paintbrush.pointed.fill")
                        .font(.system(size: 24, weight: .regular))
                        .frame(width: 32, height: 32)
                    Text("快速开始")
                        .font(.system(size: 16, weight: .semibold))
                        .tracking(1)
                }
                .foregroundStyle(.white)
                .frame(width: 166, height: 48)
                .background(Color(red: 38 / 255, green: 38 / 255, blue: 38 / 255))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.trailing, 18)
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 16)
    }
}
