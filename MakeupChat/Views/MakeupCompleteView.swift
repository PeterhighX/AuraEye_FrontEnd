import SwiftUI

/// Figma 20:1246 — 妆容完成
struct MakeupCompleteView: View {
    @Bindable var session: AppSession
    @Binding var path: NavigationPath
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var badgeHasLanded = false
    @Namespace private var badgeTransition

    var body: some View {
        ZStack {
            GradientBackgroundView()

            VStack(spacing: 0) {
                MakeupFlowHeaderView(title: "妆容完成") {
                    path = NavigationPath()
                }
                .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 24) {
                        levelCard
                        resultCard

                        HStack {
                            Capsule()
                                .fill(AppTheme.ColorToken.accentOrange)
                                .frame(width: 6, height: 22)
                            Text("上妆记录")
                                .font(.title2)
                            Spacer()
                        }
                        .padding(.horizontal, 16)

                        HStack(spacing: 12) {
                            historyCard(title: "清透甜美", tag: "少女感", colors: [
                                .init(red: 0.86, green: 0.45, blue: 0.42),
                                .init(red: 0.87, green: 0.55, blue: 0.51),
                                .init(red: 0.91, green: 0.66, blue: 0.59)
                            ])
                            historyCard(title: "中式温婉", tag: "东方韵味", colors: [
                                .init(red: 0.82, green: 0.25, blue: 0.12),
                                .init(red: 0.88, green: 0.34, blue: 0.14),
                                .init(red: 0.96, green: 0.51, blue: 0.35)
                            ])
                        }
                        .padding(.horizontal, 16)

                        Button(action: finishAndGoHome) {
                            Label("返回首页", systemImage: "house.fill")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                        }
                        .buttonStyle(.plain)
                        .background(
                            AppTheme.ColorToken.buttonPrimary,
                            in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.button)
                        )
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 36)
                }
            }

            if !badgeHasLanded {
                Image("CompletionBadge")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 176, height: 176)
                    .matchedGeometryEffect(
                        id: "completionBadge",
                        in: badgeTransition,
                        isSource: true
                    )
                    .shadow(
                        color: AppTheme.ColorToken.accentCoral.opacity(0.34),
                        radius: 22,
                        y: 12
                    )
                    .accessibilityHidden(true)
                    .transition(.scale(scale: 0.72).combined(with: .opacity))
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            session.hasCompletedFirstMakeup = true
            guard !reduceMotion else {
                badgeHasLanded = true
                return
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(750))
                withAnimation(.spring(response: 0.9, dampingFraction: 0.78)) {
                    badgeHasLanded = true
                }
            }
        }
    }

    private var levelCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("用户等级")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 5)
                    .background(AppTheme.ColorToken.accentOrange, in: Capsule())

                ProgressView(value: 0.4)
                    .tint(AppTheme.ColorToken.accentCoral)
                    .frame(width: 185)

                HStack {
                    Text("Lv. 4")
                    Spacer()
                    Text("+ 4684")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image("AvatarUser")
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 16)
        .frame(height: 104)
        .background(.white.opacity(0.45), in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.08), radius: 3, y: 2)
        .padding(.horizontal, 16)
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("你完成了")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("第 8 次的上妆")
                        .font(.title)
                    Text("2026.04.08 星期一")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image("CompletionBadge")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 82, height: 96)
                    .matchedGeometryEffect(
                        id: "completionBadge",
                        in: badgeTransition,
                        isSource: false
                    )
                    .opacity(badgeHasLanded ? 1 : 0)
                    .shadow(color: AppTheme.ColorToken.accentCoral.opacity(0.28), radius: 12, y: 8)
                    .accessibilityLabel("完成妆容勋章")
            }

            HStack(spacing: 28) {
                Label("完成率 75%", systemImage: "checkmark.circle.fill")
                Label("上妆速度 +45%", systemImage: "timer")
            }
            .font(.subheadline)

            Text("跟随化妆的感觉如何")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Text("吃力")
                LinearGradient(
                    colors: [.pink, .orange, .green],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 4)
                .overlay {
                    Circle().fill(.white).stroke(.gray.opacity(0.4)).frame(width: 12, height: 12)
                }
                Text("容易")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .padding(.horizontal, 16)
    }

    private func historyCard(title: String, tag: String, colors: [Color]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(0.5))
                    .frame(height: 120)
                    .overlay {
                        Image(systemName: "eye")
                            .font(.system(size: 38, weight: .light))
                            .foregroundStyle(.secondary)
                    }

                VStack(spacing: 6) {
                    ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                        Circle().fill(color).frame(width: 28, height: 28)
                    }
                }
            }

            Text(title).font(.body)
            Text(tag)
                .font(.caption2)
                .padding(.horizontal, 10)
                .padding(.vertical, 2)
                .background(.white.opacity(0.65), in: Capsule())
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.52), in: RoundedRectangle(cornerRadius: 18))
    }

    private func finishAndGoHome() {
        path = NavigationPath()
    }
}

#Preview {
    NavigationStack {
        MakeupCompleteView(session: AppSession(), path: .constant(NavigationPath()))
    }
}
