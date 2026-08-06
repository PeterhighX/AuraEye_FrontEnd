import SwiftUI

/// Figma 20:1246 — 妆容完成
struct MakeupCompleteView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var session: AppSession
    @Binding var path: NavigationPath
    @Binding var selectedTab: Int
    @State private var hasSavedHistory = false
    @State private var hasPlayedScrollAnimation = false
    @State private var scrollReveal: CGFloat = 0
    @State private var barSettled = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                MakeupFlowHeaderView(title: "妆容完成") {
                    path = NavigationPath()
                }
                .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 18) {
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
                            historyCard(
                                plan: MakeupLookCatalog.plan(id: session.selectedLookID),
                                time: "今天 08:42",
                                count: "第 8 次"
                            )
                            historyCard(
                                plan: MakeupLookCatalog.plan(id: "chinese_warm"),
                                time: "7月26日 19:10",
                                count: "第 7 次"
                            )
                        }
                        .padding(.horizontal, 16)

                    }
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
            }

        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            completionNavigationBar
        }
        .onAppear {
            session.hasCompletedFirstMakeup = true
            playResultScrollIfNeeded()
            guard !hasSavedHistory else { return }
            hasSavedHistory = true
            session.recordCompletedMakeup()
        }
    }

    private var completionNavigationBar: some View {
        HStack {
            completionTab(title: "首页", symbol: "house.fill", tab: .home)
            completionTab(title: "陈列柜", symbol: "square.grid.2x2.fill", tab: .cabinet)
            completionTab(title: "我的", symbol: "person.fill", tab: .profile)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.12), radius: 12, y: 5)
        .padding(.horizontal, 20)
        .padding(.bottom, 4)
    }

    private func completionTab(title: String, symbol: String, tab: AppTab) -> some View {
        Button {
            path = NavigationPath()
            selectedTab = tab.rawValue
        } label: {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 21))
                Text(title)
                    .font(.caption)
            }
            .foregroundStyle(
                tab == .profile
                    ? AppTheme.ColorToken.accentOrange
                    : Color.secondary
            )
            .frame(maxWidth: .infinity)
            .frame(height: 48)
        }
        .buttonStyle(.plain)
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
        GeometryReader { proxy in
            let cardHeight = proxy.size.width * 293 / 402
            let barHeight = cardHeight * 34 / 293
            let sheetStart = cardHeight * 14 / 293
            let revealHeight = max(0, cardHeight - sheetStart) * scrollReveal

            ZStack(alignment: .top) {
                // 清单主体固定在最终位置，通过向下增长的蒙版形成“从横条卷出”。
                Image("MakeupCompletionCardRefined")
                    .resizable()
                    .scaledToFit()
                    .frame(width: proxy.size.width, height: cardHeight)
                    .mask(alignment: .top) {
                        VStack(spacing: 0) {
                            Color.clear.frame(height: sheetStart)
                            Rectangle()
                                .frame(height: revealHeight)
                            Spacer(minLength: 0)
                        }
                    }
                    .shadow(
                        color: .black.opacity(0.08 * Double(scrollReveal)),
                        radius: 8,
                        y: 5
                    )

                // 橙色卷轴杆始终位于最上层，主体从它的背后展开。
                Image("MakeupCompletionCardRefined")
                    .resizable()
                    .scaledToFit()
                    .frame(width: proxy.size.width, height: cardHeight)
                    .frame(height: barHeight, alignment: .top)
                    .clipped()
                    .scaleEffect(x: barSettled ? 1 : 0.94, y: 1, anchor: .center)
            }
            .frame(width: proxy.size.width, height: cardHeight, alignment: .top)
        }
        .aspectRatio(402 / 293, contentMode: .fit)
        .padding(.horizontal, 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("妆容完成数据卡片")
    }

    private func playResultScrollIfNeeded() {
        guard !hasPlayedScrollAnimation else { return }
        hasPlayedScrollAnimation = true

        if reduceMotion {
            scrollReveal = 1
            barSettled = true
            return
        }

        scrollReveal = 0
        barSettled = false
        withAnimation(.spring(response: 0.42, dampingFraction: 0.76).delay(0.16)) {
            barSettled = true
        }
        withAnimation(.easeOut(duration: 1.15).delay(0.28)) {
            scrollReveal = 1
        }
    }

    private func historyCard(
        plan: MakeupLookPlan,
        time: String,
        count: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(plan.look.imageAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .scaleEffect(1.1)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(spacing: 8) {
                    ForEach(plan.look.swatchHexes, id: \.self) { hex in
                        Circle()
                            .fill(Color(completionHex: hex))
                            .frame(width: 20, height: 20)
                    }
                }
            }

            Text("\(count)上妆")
                .font(.body)

            Text(time)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.52), in: RoundedRectangle(cornerRadius: 18))
    }

}

private extension Color {
    init(completionHex: String) {
        let value = UInt64(completionHex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

#Preview {
    NavigationStack {
        MakeupCompleteView(
            session: AppSession(),
            path: .constant(NavigationPath()),
            selectedTab: .constant(AppTab.home.rawValue)
        )
    }
}
