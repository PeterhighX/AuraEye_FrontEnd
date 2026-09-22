import SwiftUI

struct AnimatedWeatherSymbol: View {
    let symbolName: String
    let size: CGFloat
    let frameWidth: CGFloat
    let frameHeight: CGFloat

    var body: some View {
        Image(systemName: symbolName)
            .symbolRenderingMode(.multicolor)
            .font(.system(size: size))
            .frame(width: frameWidth, height: frameHeight)
            .contentTransition(.symbolEffect(.replace))
            .symbolEffect(.pulse.byLayer, options: .repeating)
            .accessibilityHidden(true)
    }
}

struct WeatherSummaryCard: View {
    var aiMessage: String
    var showFirstTimeHint: Bool = false
    var weather = LiveWeatherSnapshot()

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(red: 1.0, green: 0.93, blue: 0.91).opacity(0.4))
                .shadow(color: Color.black.opacity(0.09), radius: 2, y: 2)
                .frame(height: showFirstTimeHint ? 205 : 161)
                .offset(y: 19)

            HStack(alignment: .bottom) {
                AnimatedWeatherSymbol(
                    symbolName: weather.symbolName,
                    size: 68,
                    frameWidth: 124,
                    frameHeight: 81
                )

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    HStack {
                        HStack(alignment: .top, spacing: 2) {
                            Text("\(weather.temperature)")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(Color(red: 85 / 255, green: 85 / 255, blue: 85 / 255))
                            VStack(alignment: .leading, spacing: 0) {
                                Text("℃")
                                    .font(.system(size: 10, design: .rounded))
                                Text(weather.conditionText)
                                    .font(.system(size: 10, design: .rounded))
                            }
                            .foregroundStyle(Color(red: 157 / 255, green: 157 / 255, blue: 157 / 255))
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 1) {
                            Text(weather.district)
                                .font(.system(size: 12, weight: .light))
                                .padding(.horizontal, 6)
                                .frame(height: 18)
                                .background(Color.white.opacity(0.45))
                                .clipShape(Capsule())
                            Link("Open-Meteo", destination: LiveWeatherSnapshot.dataSourceURL)
                                .font(.system(size: 8, weight: .light))
                        }
                        .foregroundStyle(Color(red: 102 / 255, green: 102 / 255, blue: 102 / 255))
                    }

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.45))
                            .frame(height: 9)
                        GeometryReader { proxy in
                            Capsule()
                                .fill(Color(red: 1.0, green: 139 / 255, blue: 104 / 255))
                                .frame(width: proxy.size.width * weather.uvProgress, height: 9)
                        }
                    }
                    .frame(width: 183)

                    HStack {
                        HStack(spacing: 3) {
                            Image(systemName: "sun.max.fill")
                                .font(.system(size: 12))
                            Text("紫外线指数")
                                .font(.system(size: 12))
                        }
                        Text("\(weather.uvIndex)")
                            .font(.system(size: 12))
                        Spacer()
                        Text(weather.uvDescription)
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(Color(red: 102 / 255, green: 102 / 255, blue: 102 / 255))
                    .frame(width: 183)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)

            HStack(alignment: .top, spacing: 12) {
                Image(showFirstTimeHint ? "FirstTimeAssistant" : "AvatarAI")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())

                Text(aiMessage)
                    .font(.system(size: 14, weight: .thin))
                    .foregroundStyle(Color(red: 51 / 255, green: 51 / 255, blue: 51 / 255))
                    .lineSpacing(4)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.75))
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 0,
                            bottomLeadingRadius: 13,
                            bottomTrailingRadius: 13,
                            topTrailingRadius: 13
                        )
                    )
            }
            .padding(.horizontal, 16)
            .offset(y: 109)
        }
        .frame(height: showFirstTimeHint ? 224 : 180)
        .padding(.horizontal, 16)
    }
}
