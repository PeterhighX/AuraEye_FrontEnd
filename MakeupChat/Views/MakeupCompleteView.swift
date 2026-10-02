import SwiftUI
import UIKit

/// 完成页只展示同一事务返回的会话结果与全局成长账户。
struct MakeupCompleteView: View {
    @Bindable var session: AppSession
    @Binding var path: NavigationPath
    @Binding var selectedTab: Int
    @State private var feedbackRating: Int?
    @State private var feedbackRequestID: String?
    @State private var feedbackMessage: String?
    @State private var isSubmittingFeedback = false

    private var completion: MakeupCompletionDTO? { session.business.completion }

    var body: some View {
        VStack(spacing: 0) {
            MakeupFlowHeaderView(title: "妆容完成") {
                path = NavigationPath()
            }
            .padding(.top, 8)

            ScrollView {
                VStack(spacing: 18) {
                    if let completion {
                        levelCard(completion)
                        resultCard(completion)
                        feedbackCard
                        if let stats = session.business.makeupStats {
                            statsCard(stats)
                        } else if let error = session.business.statsError {
                            Text("统计暂不可用：\(error)")
                                .font(.caption).foregroundStyle(.secondary)
                        }

                        HStack {
                            Capsule()
                                .fill(AppTheme.ColorToken.accentOrange)
                                .frame(width: 6, height: 22)
                            Text("上妆记录").font(.title2)
                            Spacer()
                        }
                        .padding(.horizontal, 16)

                        if session.business.makeupHistory.isEmpty {
                            Text(session.business.historyError.map { "记录暂不可用：\($0)" } ?? "暂无其他上妆记录")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(session.business.makeupHistory.prefix(5)) { item in
                                        MakeupHistoryCard(item: item, styles: session.business.styles)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    } else {
                        ContentUnavailableView(
                            "完成结果未同步",
                            systemImage: "clock.arrow.circlepath",
                            description: Text("请等待服务端确认上妆完成；本机不会计算等级或奖励。")
                        )
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) { completionNavigationBar }
        .task {
            if session.business.styles.isEmpty { await session.business.refreshStyles() }
            await session.business.refreshHistory()
            await session.business.refreshStats()
            await session.business.refreshGrowth()
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
                Image(systemName: symbol).font(.system(size: 21))
                Text(title).font(.caption)
            }
            .foregroundStyle(tab == .profile ? AppTheme.ColorToken.accentOrange : Color.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
        }
        .buttonStyle(.plain)
    }

    private func levelCard(_ result: MakeupCompletionDTO) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("用户等级")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 5)
                    .background(AppTheme.ColorToken.accentOrange, in: Capsule())

                ProgressView(value: min(max(result.growthOverview.levelProgress, 0), 1))
                    .tint(AppTheme.ColorToken.accentCoral)
                    .frame(width: 185)

                HStack {
                    Text("Lv. \(result.growthOverview.level)")
                    Spacer()
                    Text("+ \(result.growthDelta.xpAwarded) XP")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Group {
                if let data = session.business.avatarData,
                   let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFit()
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable().scaledToFit().padding(16)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 72, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 16)
        .frame(height: 104)
        .background(.white.opacity(0.45), in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.08), radius: 3, y: 2)
        .padding(.horizontal, 16)
    }

    private func resultCard(_ result: MakeupCompletionDTO) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("第 \(result.ordinal) 次上妆完成")
                .font(.title2.weight(.semibold))
            Text("完成率 \(Int(result.completionRate * 100))%")
            Text("有效上妆时长 \(result.activeDurationMS / 60_000) 分钟")
            Text("本次经验 +\(result.growthDelta.xpAwarded) XP")
            Text("本次积分 +\(result.growthDelta.pointsAwarded)")
        }
        .font(.callout)
        .foregroundStyle(AppTheme.ColorToken.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
    }

    private var feedbackCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("评价本次教程").font(.headline)
            HStack(spacing: 14) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        feedbackRating = value
                        feedbackRequestID = UUID().uuidString
                    } label: {
                        Image(systemName: value <= (feedbackRating ?? 0) ? "star.fill" : "star")
                            .foregroundStyle(AppTheme.ColorToken.accentOrange)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(value) 星")
                }
            }
            if let feedbackMessage {
                Text(feedbackMessage).font(.caption).foregroundStyle(.secondary)
            }
            Button(isSubmittingFeedback ? "正在提交…" : "提交评价") {
                submitFeedback()
            }
            .disabled(feedbackRating == nil || isSubmittingFeedback)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 16)
    }

    private func statsCard(_ stats: MakeupStatsDTO) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("上妆统计").font(.headline)
            Text("累计完成 \(stats.completedCount) 次 · 历史完成率 \(Int(stats.completionRate * 100))%")
            if let duration = stats.averageActiveDurationMS {
                Text("平均有效时长 \(duration / 60_000) 分钟")
            }
            if let speed = stats.speedComparison {
                Text("同风格可比记录 \(speed.comparableSessionCount) 次 · 速度提升 \(Int(speed.percentFaster))%")
            } else {
                Text("暂无可比上妆速度记录")
            }
        }
        .font(.callout)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 16)
    }

    private func submitFeedback() {
        guard let sessionID = session.business.activeSession?.sessionID,
              let rating = feedbackRating else { return }
        let requestID = feedbackRequestID ?? UUID().uuidString
        feedbackRequestID = requestID
        isSubmittingFeedback = true
        Task {
            defer { isSubmittingFeedback = false }
            do {
                try await BusinessDataService.shared.submitFeedback(
                    sessionID: sessionID, requestID: requestID, rating: rating
                )
                feedbackMessage = "评价已保存"
                await session.business.refreshHistory()
                await session.business.refreshStats()
            } catch {
                feedbackMessage = "评价暂未保存：\(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    NavigationStack {
        MakeupCompleteView(
            session: AppSession(), path: .constant(NavigationPath()),
            selectedTab: .constant(AppTab.home.rawValue)
        )
    }
}
