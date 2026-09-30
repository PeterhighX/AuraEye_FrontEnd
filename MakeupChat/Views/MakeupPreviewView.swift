import SwiftUI
import UIKit

/// 浏览风格不调用玩美；用户确认后才由后端生成计划。
struct MakeupPreviewView: View {
    @Bindable var session: AppSession
    @Binding var path: NavigationPath
    @Environment(\.dismiss) private var dismiss

    @State private var selectedStyleIndex = 0
    @State private var usesAutomaticStyle = false
    @State private var isStylesLoading = true
    @State private var expandedStepID: String?
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var planRequestID: String?
    @State private var sessionRequestID: String?
    @State private var renderedImage: UIImage?
    @State private var renderedPlanID: String?
    @State private var renderMessage: String?

    private let stepColors: [Color] = [
        Color(red: 253 / 255, green: 235 / 255, blue: 235 / 255),
        Color(red: 1, green: 225 / 255, blue: 216 / 255),
        Color(red: 1, green: 193 / 255, blue: 174 / 255),
        Color(red: 1, green: 154 / 255, blue: 124 / 255),
        Color(red: 231 / 255, green: 108 / 255, blue: 69 / 255)
    ]

    private var styles: [MakeupStyleDTO] { session.business.styles }

    private var selectedStyle: MakeupStyleDTO? {
        guard !usesAutomaticStyle else { return nil }
        guard styles.indices.contains(selectedStyleIndex) else { return nil }
        return styles[selectedStyleIndex]
    }

    private var generatedPlan: MakeupPlanDTO? {
        guard let plan = session.business.activePlan else { return nil }
        if let style = selectedStyle, plan.styleID != style.id { return nil }
        return plan
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
                        LiveWeatherSummaryCard(
                            aiMessage: "今日天气多云，气温26℃，紫外线指数偏弱，可以放心大胆的出门哦！",
                            surface: generatedPlan == nil ? "quick_start_preview" : "generated_preview",
                            styleID: selectedStyle?.id
                        )

                        KnowledgeTipBar(
                            surface: generatedPlan == nil ? "quick_start_preview" : "generated_preview"
                        )

                        if let style = selectedStyle {
                            styleCard(style)
                        } else if !isStylesLoading && session.business.stylesError == nil {
                            automaticStyleCard
                        } else {
                            Text(session.business.stylesError.map { "妆容风格暂不可用：\($0)" } ?? "正在读取妆容风格…")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .padding(24)
                        }

                        if let plan = generatedPlan {
                            renderCard(plan)
                        }

                        if let plan = generatedPlan, plan.status == "ready" {
                            VStack(spacing: 12) {
                                ForEach(plan.steps) { step in
                                    stepCard(step, index: step.order)
                                }
                            }
                            .padding(.horizontal, 16)
                        } else if selectedStyle != nil || (!isStylesLoading && session.business.stylesError == nil) {
                            Text("选择妆容后点击“生成妆容”，步骤会根据你的档案和化妆品生成。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 20)
                        }
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }

            if isSubmitting {
                OperationTransitionOverlay(
                    message: generatedPlan == nil ? "正在生成你的上妆预览…" : "正在准备上妆步骤…",
                    surface: "quick_start_preview"
                )
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task {
            if styles.isEmpty { await session.business.refreshStyles() }
            isStylesLoading = false
            usesAutomaticStyle = styles.isEmpty && session.business.stylesError == nil
            await session.business.refreshProfile()
            if let index = styles.firstIndex(where: { $0.id == session.selectedLookID }) {
                selectedStyleIndex = index
            }
        }
        .task(id: generatedPlan?.planID) {
            renderedImage = nil
            renderedPlanID = nil
            renderMessage = nil
            if let plan = generatedPlan { await loadRender(for: plan) }
        }
        .alert("妆容暂不可用", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "请稍后重试。")
        }
    }

    private func styleCard(_ style: MakeupStyleDTO) -> some View {
        HStack(spacing: 12) {
            Group {
                if let key = style.heroAssetKey, UIImage(named: key) != nil {
                    Image(key).resizable().scaledToFill()
                } else {
                    Image(systemName: "paintpalette.fill")
                        .resizable().scaledToFit().padding(28)
                        .foregroundStyle(AppTheme.ColorToken.accentOrange)
                }
            }
            .frame(width: 120, height: 120)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(style.title).font(.system(size: 16, weight: .light))
                        Text(style.tag).font(.system(size: 11, weight: .light))
                    }
                    Spacer()
                    Button {
                        guard !styles.isEmpty else { return }
                        withAnimation(.easeInOut(duration: 0.22)) {
                            selectedStyleIndex = (selectedStyleIndex + 1) % styles.count
                            usesAutomaticStyle = false
                            session.selectLook(id: styles[selectedStyleIndex].id)
                            expandedStepID = nil
                            planRequestID = nil
                            sessionRequestID = nil
                        }
                    } label: {
                        Image("PreviewSwitch")
                            .resizable().scaledToFit().frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("切换推荐妆容")
                }

                Text(generatedPlan?.summary ?? style.summary)
                    .font(.system(size: 12, weight: .light))
                    .lineSpacing(4)

                HStack {
                    ForEach(generatedPlan?.swatchHexes ?? style.swatchHexes, id: \.self) { hex in
                        Circle().fill(Color(previewHex: hex)).frame(width: 24, height: 24)
                    }
                    Spacer()
                    Button {
                        if let plan = generatedPlan, plan.status == "ready" {
                            beginPractice(plan)
                        } else {
                            generatePlan(style)
                        }
                    } label: {
                        Text(generatedPlan?.status == "ready" ? "开始上妆" : "生成妆容")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(red: 0.15, green: 0.15, blue: 0.15))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isSubmitting)
                }
            }
        }
        .padding(12)
        .frame(height: 136)
        .background(Color.white.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card))
        .shadow(color: .black.opacity(0.09), radius: 2, y: 2)
        .padding(.horizontal, 16)
    }

    private var automaticStyleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(generatedPlan?.title ?? "让 AI 推荐妆容风格")
                .font(.headline)
            Text(generatedPlan?.summary ?? "将根据真实面部分析和你已确认的化妆品生成合适的眼妆。")
                .font(.callout).foregroundStyle(.secondary)
            Button(generatedPlan?.status == "ready" ? "开始上妆" : "生成妆容") {
                if let plan = generatedPlan, plan.status == "ready" {
                    beginPractice(plan)
                } else {
                    generatePlan(nil)
                }
            }
            .disabled(isSubmitting)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 16)
    }

    private func stepCard(_ step: MakeupPlanStepDTO, index: Int) -> some View {
        let expanded = expandedStepID == step.id
        return Button {
            withAnimation(.spring(response: 0.46, dampingFraction: 0.82)) {
                expandedStepID = expanded ? nil : step.id
            }
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                Text("step \(index)  \(step.title)")
                    .font(.system(size: 17, weight: .semibold))
                if expanded {
                    styledMakeupInstruction(step.instruction, bullet: true)
                        .font(.system(size: 15, weight: .light))
                        .multilineTextAlignment(.leading)
                }
            }
            .foregroundStyle(Color(red: 0.15, green: 0.15, blue: 0.15))
            .frame(maxWidth: .infinity, minHeight: expanded ? 185 : 92, alignment: .topLeading)
            .padding(16)
            .background(stepColors[(max(index, 1) - 1) % stepColors.count])
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card))
        }
        .buttonStyle(.plain)
    }

    private func renderCard(_ plan: MakeupPlanDTO) -> some View {
        VStack(spacing: 8) {
            if renderedPlanID == plan.planID, let renderedImage {
                Image(uiImage: renderedImage)
                    .resizable().scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            } else {
                Image(systemName: "person.crop.rectangle")
                    .font(.system(size: 48))
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
                    .foregroundStyle(.secondary)
            }
            Text(renderMessage ?? "妆容文字已就绪，真实试妆图生成中…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 16)
    }

    private func loadRender(for plan: MakeupPlanDTO) async {
        for _ in 0..<30 {
            guard !Task.isCancelled else { return }
            do {
                let current = try await BusinessDataService.shared.plan(id: plan.planID)
                guard current.planID == plan.planID else { throw APIClientError.invalidResponse }
                if current.render.status == "failed" || current.render.status == "skipped" {
                    renderMessage = current.render.status == "failed" ? "试妆图生成失败，文字步骤仍可使用。" : "本次未生成试妆图。"
                    return
                }
                if current.render.status == "succeeded", let jobID = current.render.jobID,
                   let _ = try await BusinessDataService.shared.renderResult(jobID: jobID) {
                    let data = try await BusinessDataService.shared.renderResultImage(jobID: jobID)
                    guard !Task.isCancelled, let image = UIImage(data: data) else { return }
                    renderedImage = image
                    renderedPlanID = plan.planID
                    renderMessage = "真实试妆效果"
                    return
                }
            } catch {
                renderMessage = "试妆图暂不可用：\(error.localizedDescription)"
                return
            }
            try? await Task.sleep(for: .seconds(2))
        }
        renderMessage = "试妆图仍在生成，请稍后重试。"
    }

    private func generatePlan(_ style: MakeupStyleDTO?) {
        guard let sourceJobID = session.business.visualProfile?.sourceJobID else {
            errorMessage = "请先完成真实面部分析，再生成妆容。"
            return
        }
        guard session.business.visualProfile?.resultSource == "remote_provider" else {
            errorMessage = "当前档案来自演示分析，请重新完成真实面部分析。"
            return
        }
        let requestID = planRequestID ?? UUID().uuidString
        planRequestID = requestID
        isSubmitting = true
        Task {
            defer { isSubmitting = false }
            do {
                let ticket = try await BusinessDataService.shared.createPlan(
                    requestID: requestID, portraitJobID: sourceJobID, styleID: style?.id,
                    weather: currentWeatherContext()
                )
                for _ in 0..<30 {
                    let plan = try await BusinessDataService.shared.plan(id: ticket.planID)
                    if plan.status == "ready" {
                        guard (style == nil || plan.styleID == style?.id),
                              (plan.portrait == nil || plan.portrait?.sourceJobID == sourceJobID) else {
                            throw APIClientError.invalidResponse
                        }
                        session.business.install(plan: plan)
                        return
                    }
                    if plan.status == "failed" {
                        planRequestID = nil
                        errorMessage = "妆容生成失败，请修改选择后重试。"
                        return
                    }
                    try await Task.sleep(for: .milliseconds(max(500, min(ticket.pollAfterMS, 10_000))))
                }
                errorMessage = "生成时间较长，请稍后重新进入查看。"
            } catch {
                if (error as? APIClientError)?.problemCode == "INSUFFICIENT_POINTS" {
                    await session.business.refreshGrowth()
                }
                errorMessage = error.localizedDescription
            }
        }
    }

    private func currentWeatherContext() -> WeatherContextDTO? {
        let snapshot = LiveWeatherProvider.shared.snapshot
        guard let observedAt = snapshot.observedAt,
              let temperature = snapshot.temperature,
              let condition = snapshot.conditionText,
              let uvIndex = snapshot.uvIndex else { return nil }
        return WeatherContextDTO(
            temperatureC: temperature, condition: condition, uvIndex: uvIndex,
            district: snapshot.district,
            observedAt: ISO8601DateFormatter().string(from: observedAt)
        )
    }

    private func beginPractice(_ plan: MakeupPlanDTO) {
        let requestID = sessionRequestID ?? UUID().uuidString
        sessionRequestID = requestID
        isSubmitting = true
        Task {
            defer { isSubmitting = false }
            do {
                let practice = try await BusinessDataService.shared.startSession(
                    requestID: requestID, planID: plan.planID
                )
                session.business.install(session: practice)
                path.append(AppRoute.makeupSteps)
            } catch {
                errorMessage = error.localizedDescription
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
