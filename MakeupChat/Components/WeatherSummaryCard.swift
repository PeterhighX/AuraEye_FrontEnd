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
            .symbolEffect(.pulse.byLayer, options: .repeating.speed(0.35))
            .accessibilityHidden(true)
    }
}

struct LiveWeatherSummaryCard: View {
    let aiMessage: String
    var showFirstTimeHint = false
    @StateObject private var weatherProvider = LiveWeatherProvider()

    var body: some View {
        WeatherSummaryCard(
            aiMessage: aiMessage,
            showFirstTimeHint: showFirstTimeHint,
            weather: weatherProvider.snapshot,
            onRefreshWeather: { weatherProvider.start() }
        )
        .task {
            while !Task.isCancelled {
                weatherProvider.start()
                do {
                    try await Task.sleep(for: .seconds(30 * 60))
                } catch {
                    break
                }
            }
        }
    }
}

struct WeatherSummaryCard: View {
    var aiMessage: String
    var showFirstTimeHint: Bool = false
    var weather = LiveWeatherSnapshot()
    var onRefreshWeather: () -> Void = {}

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(red: 1.0, green: 0.93, blue: 0.91).opacity(0.4))
                .shadow(color: Color.black.opacity(0.09), radius: 2, y: 2)
                .frame(height: showFirstTimeHint ? 205 : 161)
                .offset(y: 19)

            Button(action: onRefreshWeather) {
                HStack(alignment: .bottom, spacing: 0) {
                    PreviewWeatherAnimation(weather: weather)
                        .frame(width: 124, height: 100, alignment: .bottom)

                    Spacer()

                    PreviewWeatherData(weather: weather)
                        .frame(width: 183, alignment: .bottomTrailing)
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 85, maxHeight: 85, alignment: .bottom)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("刷新天气")
            .accessibilityValue("\(weather.conditionText ?? "多云")，\(weather.temperature ?? 25)度")

            PreviewAgentOutput(
                message: aiMessage,
                usesFirstTimeAvatar: showFirstTimeHint
            )
            .frame(
                maxWidth: .infinity,
                minHeight: showFirstTimeHint ? 105 : 58,
                maxHeight: showFirstTimeHint ? 105 : 58,
                alignment: .top
            )
            .padding(.horizontal, 16)
            .offset(y: 109)
        }
        .frame(height: showFirstTimeHint ? 230 : 186)
        .padding(.horizontal, 16)
    }
}

private struct PreviewWeatherAnimation: View {
    let weather: LiveWeatherSnapshot

    var body: some View {
        if let symbolName = weather.symbolName {
            AnimatedWeatherSymbol(
                symbolName: symbolName,
                size: 100,
                frameWidth: 124,
                frameHeight: 100
            )
        }
    }
}

private struct PreviewWeatherData: View {
    let weather: LiveWeatherSnapshot

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack {
                HStack(alignment: .top, spacing: 2) {
                    Text(weather.temperature.map(String.init) ?? "--")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color(red: 85 / 255, green: 85 / 255, blue: 85 / 255))
                    VStack(alignment: .leading, spacing: 0) {
                        Text("℃")
                        Text(weather.conditionText ?? "加载中")
                    }
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(Color(red: 157 / 255, green: 157 / 255, blue: 157 / 255))
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(weather.district)
                        .font(.system(size: 12, weight: .light))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 6)
                        .frame(height: 18)
                        .background(Color.white.opacity(0.45))
                        .clipShape(Capsule())
                    Text("Open-Meteo")
                        .font(.system(size: 8, weight: .light))
                }
                .foregroundStyle(Color(red: 102 / 255, green: 102 / 255, blue: 102 / 255))
            }

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.45))
                GeometryReader { proxy in
                    Capsule()
                        .fill(Color(red: 1.0, green: 139 / 255, blue: 104 / 255))
                        .frame(width: proxy.size.width * weather.uvProgress)
                }
            }
            .frame(height: 9)

            HStack(spacing: 4) {
                Label("紫外线指数", systemImage: "sun.max.fill")
                Text(weather.uvIndex.map(String.init) ?? "--")
                Spacer(minLength: 2)
                Text(weather.uvDescription)
            }
            .font(.system(size: 12))
            .foregroundStyle(Color(red: 102 / 255, green: 102 / 255, blue: 102 / 255))
        }
    }
}

private struct PreviewAgentOutput: View {
    let message: String
    let usesFirstTimeAvatar: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(usesFirstTimeAvatar ? "FirstTimeAssistant" : "AvatarAI")
                .resizable()
                .scaledToFill()
                .frame(width: 36, height: 36)
                .clipShape(Circle())

            Text(message)
                .font(.system(size: 13, weight: .thin))
                .foregroundStyle(Color(red: 51 / 255, green: 51 / 255, blue: 51 / 255))
                .lineSpacing(3)
                .lineLimit(usesFirstTimeAvatar ? 4 : 2)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
    }
}
