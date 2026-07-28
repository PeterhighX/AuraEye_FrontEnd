import SwiftUI

struct GradientBackgroundView: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.60, blue: 0.42),
                Color(red: 0.96, green: 0.66, blue: 0.85),
                Color(red: 0.72, green: 0.74, blue: 1.0),
                Color(red: 0.83, green: 0.85, blue: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

/// 首页专用背景：顶部珊瑚粉光晕、渐隐波点与下方淡紫粉过渡。
struct HomeBackgroundView: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Color.white

                LinearGradient(
                    stops: [
                        .init(color: Color(red: 1.00, green: 0.84, blue: 0.82), location: 0.00),
                        .init(color: Color(red: 1.00, green: 0.75, blue: 0.78), location: 0.28),
                        .init(color: Color(red: 0.95, green: 0.82, blue: 0.94), location: 0.56),
                        .init(color: Color(red: 1.00, green: 0.90, blue: 0.95), location: 0.78),
                        .init(color: .white, location: 1.00)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 525)

                RadialGradient(
                    colors: [
                        Color(red: 1.00, green: 0.47, blue: 0.31).opacity(0.55),
                        Color(red: 1.00, green: 0.62, blue: 0.55).opacity(0.22),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 190
                )
                .frame(width: 390, height: 260)
                .offset(x: proxy.size.width * 0.22, y: -25)

                RadialGradient(
                    colors: [
                        Color(red: 0.74, green: 0.70, blue: 1.00).opacity(0.32),
                        Color(red: 0.88, green: 0.74, blue: 0.96).opacity(0.17),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 205
                )
                .frame(width: 410, height: 350)
                .offset(x: -proxy.size.width * 0.30, y: 150)

                RadialGradient(
                    colors: [
                        Color(red: 1.00, green: 0.66, blue: 0.76).opacity(0.22),
                        Color(red: 1.00, green: 0.78, blue: 0.86).opacity(0.10),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 205
                )
                .frame(width: 410, height: 350)
                .offset(x: proxy.size.width * 0.32, y: 185)

                DotPatternView()
                    .frame(width: proxy.size.width, height: 220)
            }
        }
        .ignoresSafeArea()
    }
}

/// 用户档案页背景：Figma 20:709 的橙粉顶部、紫粉光晕与向白色的长过渡。
struct ProfileDetailBackgroundView: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Color.white

                LinearGradient(
                    stops: [
                        .init(color: Color(red: 1.00, green: 0.82, blue: 0.80), location: 0.00),
                        .init(color: Color(red: 1.00, green: 0.72, blue: 0.75), location: 0.25),
                        .init(color: Color(red: 0.94, green: 0.84, blue: 0.98), location: 0.52),
                        .init(color: Color(red: 1.00, green: 0.88, blue: 0.94), location: 0.76),
                        .init(color: .white, location: 1.00)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 800)

                RadialGradient(
                    colors: [
                        Color(red: 1.00, green: 0.47, blue: 0.31).opacity(0.48),
                        Color(red: 1.00, green: 0.66, blue: 0.58).opacity(0.18),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 210
                )
                .frame(width: 430, height: 310)
                .offset(x: proxy.size.width * 0.24, y: -48)

                RadialGradient(
                    colors: [
                        Color(red: 0.70, green: 0.67, blue: 1.00).opacity(0.30),
                        Color(red: 0.86, green: 0.75, blue: 0.98).opacity(0.14),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 235
                )
                .frame(width: 470, height: 430)
                .offset(x: -proxy.size.width * 0.31, y: 250)

                RadialGradient(
                    colors: [
                        Color(red: 1.00, green: 0.64, blue: 0.76).opacity(0.22),
                        Color(red: 1.00, green: 0.79, blue: 0.87).opacity(0.09),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 230
                )
                .frame(width: 460, height: 420)
                .offset(x: proxy.size.width * 0.34, y: 285)

                DotPatternView(diameter: 8, spacing: 12, baseOpacity: 0.30)
                    .frame(width: proxy.size.width, height: 305)
            }
        }
        .ignoresSafeArea()
    }
}

/// 正式跟练页背景：顶部留白，渐变与波点从眼部示意下方开始。
struct MakeupPracticeBackgroundView: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Color.white

                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.97, blue: 0.95),
                        Color(red: 0.95, green: 0.84, blue: 0.98),
                        Color(red: 1.0, green: 0.70, blue: 0.72),
                        Color(red: 1.0, green: 0.93, blue: 0.95)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: max(520, proxy.size.height - 350))
                .offset(y: 350)

                RadialGradient(
                    colors: [
                        Color(red: 0.72, green: 0.67, blue: 1.0).opacity(0.32),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 220
                )
                .frame(width: 440, height: 420)
                .offset(x: -150, y: 430)

                RadialGradient(
                    colors: [
                        Color(red: 1.0, green: 0.45, blue: 0.46).opacity(0.30),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 230
                )
                .frame(width: 460, height: 430)
                .offset(x: 160, y: 390)

                DotPatternView(diameter: 7, spacing: 11, baseOpacity: 0.22)
                    .frame(width: proxy.size.width, height: 250)
                    .offset(y: 570)
            }
        }
        .ignoresSafeArea()
    }
}

private struct DotPatternView: View {
    var diameter: CGFloat = 8
    var spacing: CGFloat = 12
    var baseOpacity: Double = 0.26

    var body: some View {
        Canvas { context, size in
            for y in stride(from: CGFloat(2), through: size.height, by: spacing) {
                let fade = max(0, 1 - y / size.height)
                let opacity = baseOpacity * fade * fade

                for x in stride(from: CGFloat(8), through: size.width, by: spacing) {
                    let dot = CGRect(x: x, y: y, width: diameter, height: diameter)
                    context.fill(
                        Path(ellipseIn: dot),
                        with: .color(.white.opacity(opacity))
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}
