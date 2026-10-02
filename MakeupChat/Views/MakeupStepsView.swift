import SwiftUI
import UIKit

/// 手势保留原卡片阻力；当前步骤、完成进度和解释以服务端会话为准。
struct MakeupStepsView: View {
    @Bindable var session: AppSession
    @Binding var path: NavigationPath
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var horizontalDrag: CGFloat = 0
    @State private var needsExplanation = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var portraitImage: UIImage?
    @State private var visibleStartedAt = Date.now
    @State private var isForegroundVisible = true
    @State private var completeRequestID: String?
    @State private var pendingSwipeSignature: String?
    @State private var pendingSwipeEventID: String?
    @State private var pendingExplainStepID: String?
    @State private var pendingExplainEventID: String?

    private var plan: MakeupPlanDTO? { session.business.activePlan }
    private var practice: MakeupSessionDTO? { session.business.activeSession }

    var body: some View {
        VStack(spacing: 0) {
            MakeupFlowHeaderView(title: "上妆步骤", usesPreviewAssets: true) {
                dismiss()
            }
            .padding(.top, 8)

            if let plan, let practice,
               !session.isDemoAccount || session.demoRunError == nil,
               !session.isDemoAccount || (session.demoRun?.activePlanID == plan.planID && session.demoRun?.activeSessionID == practice.sessionID),
               let stepID = practice.currentStepID,
               let step = plan.steps.first(where: { $0.id == stepID }) {
                practiceContent(plan: plan, practice: practice, step: step)
            } else {
                ContentUnavailableView(
                    "上妆会话未就绪",
                    systemImage: "paintbrush.pointed",
                    description: Text("请从妆容预览生成计划并开始上妆。")
                )
                .frame(maxHeight: .infinity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task(id: plan?.planID) {
            portraitImage = nil
            if let plan { await loadPortrait(for: plan) }
        }
        .onAppear {
            visibleStartedAt = .now
            isForegroundVisible = scenePhase == .active
        }
        .onDisappear {
            if isForegroundVisible {
                reportStepExit()
                isForegroundVisible = false
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                visibleStartedAt = .now
                isForegroundVisible = true
            } else if isForegroundVisible {
                reportStepExit()
                isForegroundVisible = false
            }
        }
        .alert("步骤暂未更新", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "请稍后重试。")
        }
    }

    private func practiceContent(
        plan: MakeupPlanDTO, practice: MakeupSessionDTO, step: MakeupPlanStepDTO
    ) -> some View {
        let currentIndex = plan.steps.firstIndex(where: { $0.id == step.id }) ?? 0
        return VStack(spacing: 0) {
            progressCard(plan: plan, practice: practice, step: step, index: currentIndex)
                .padding(.top, 24)

            Image(previewAssetName(for: step))
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 90)
                .clipped()
                .contentShape(Rectangle())
                .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 24))
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .accessibilityLabel("第 \(currentIndex + 1) 步眼部线条预览")

            resistantPager(plan: plan, practice: practice, currentIndex: currentIndex)
                .frame(height: 422)
                .padding(.top, 20)

            if let tip = step.tip, !tip.isEmpty {
                Text("小提示：\(tip)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
            }
            KnowledgeTipBar(surface: "makeup_step", planID: plan.planID, stepID: step.id)
                .padding(.top, 8)
            Spacer(minLength: 8)
        }
    }

    private func progressCard(
        plan: MakeupPlanDTO, practice: MakeupSessionDTO,
        step: MakeupPlanStepDTO, index: Int
    ) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Step \(index + 1)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 92, height: 32)
                        .background(AppTheme.ColorToken.textPrimary,
                                    in: RoundedRectangle(cornerRadius: 12))
                    Text(step.title).font(.title3).fontDesign(.rounded)
                }

                ProgressView(
                    value: Double(practice.completedStepCount),
                    total: Double(max(practice.totalStepCount, 1))
                )
                .tint(AppTheme.ColorToken.accentCoral)

                Text("\(Int(Double(practice.completedStepCount) / Double(max(practice.totalStepCount, 1)) * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
            ZStack(alignment: .bottom) {
                if let portraitImage {
                    Image(uiImage: portraitImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                } else {
                    Image(systemName: "person.crop.rectangle")
                        .resizable().scaledToFit().padding(16)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 88, height: 103, alignment: .bottom)
            .clipped()
            .accessibilityLabel("本次计划的人物效果预览")
        }
        .padding(.horizontal, 16)
        .frame(height: 103)
        .background(Color(red: 1, green: 237 / 255, blue: 232 / 255).opacity(0.4),
                    in: RoundedRectangle(cornerRadius: 24))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.08), radius: 3, y: 2)
        .padding(.horizontal, 16)
    }

    private func resistantPager(
        plan: MakeupPlanDTO, practice: MakeupSessionDTO, currentIndex: Int
    ) -> some View {
        GeometryReader { proxy in
            let cardWidth = min(CGFloat(270), proxy.size.width - 96)
            let pageStride = cardWidth + 24
            HStack(spacing: 24) {
                ForEach(Array(plan.steps.enumerated()), id: \.element.id) { index, step in
                    tutorialCard(step: step, isCurrent: index == currentIndex,
                                 explanation: practice.explanation)
                        .frame(width: cardWidth)
                        .scaleEffect(index == currentIndex ? 1 : 0.94)
                        .blur(radius: index == currentIndex ? 0 : 7)
                        .opacity(index == currentIndex ? 1 : 0.42)
                        .accessibilityHidden(index != currentIndex)
                }
            }
            .offset(x: (proxy.size.width - cardWidth) / 2
                    - CGFloat(currentIndex) * pageStride + horizontalDrag)
            .contentShape(Rectangle())
            .gesture(pagerGesture(plan: plan, practice: practice,
                                  step: plan.steps[currentIndex]))
            .animation(.spring(response: 0.52, dampingFraction: 0.88), value: currentIndex)
        }
        .clipped()
    }

    private func tutorialCard(
        step: MakeupPlanStepDTO, isCurrent: Bool, explanation: String?
    ) -> some View {
        VStack(spacing: 22) {
            HStack {
                Text("当前工具").font(.headline).foregroundStyle(.secondary)
                Spacer()
                Text(step.toolName ?? "按教程操作").font(.headline).underline()
            }

            Image("EyelinerProductIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 112, height: 112)
                .accessibilityLabel(step.toolName ?? "当前工具")

            styledMakeupInstruction(step.instruction)
                .font(.callout)
                .fontWeight(.light)
                .foregroundStyle(AppTheme.ColorToken.textSecondary)
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .topLeading)

            if isCurrent, needsExplanation {
                if let explanation, !explanation.isEmpty {
                    Text(explanation).font(.caption).foregroundStyle(.secondary)
                } else {
                    Button(isSubmitting ? "讲解生成中…" : "需要讲解") {
                        requestExplanation(step)
                    }
                    .disabled(isSubmitting)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(height: 380, alignment: .top)
        .background(.white.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }

    private func previewAssetName(for step: MakeupPlanStepDTO) -> String {
        if let key = step.previewAssetKey, UIImage(named: key) != nil { return key }
        let order = min(max(step.order, 1), 5)
        return "PracticeStep\(order)"
    }

    private func pagerGesture(
        plan: MakeupPlanDTO, practice: MakeupSessionDTO, step: MakeupPlanStepDTO
    ) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard !isSubmitting, abs(value.translation.width) > abs(value.translation.height) else { return }
                horizontalDrag = value.translation.width * 0.38
            }
            .onEnded { value in
                guard !isSubmitting else { return }
                if abs(value.translation.height) > abs(value.translation.width) {
                    if value.translation.height < -60 { needsExplanation = true }
                    sendSwipe("up", committed: value.translation.height < -60,
                              step: step, practice: practice, plan: plan)
                } else {
                    let direction = value.translation.width < 0 ? "left" : "right"
                    let committed = abs(value.translation.width) > 230
                    sendSwipe(direction, committed: committed,
                              step: step, practice: practice, plan: plan)
                }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) {
                    horizontalDrag = 0
                }
            }
    }

    private func sendSwipe(
        _ direction: String, committed: Bool, step: MakeupPlanStepDTO,
        practice: MakeupSessionDTO, plan: MakeupPlanDTO
    ) {
        guard !session.isDemoAccount || session.demoRun?.activeSessionID == practice.sessionID else { return }
        isSubmitting = true
        let visibleMS = visibleDurationMS()
        let signature = "\(practice.sessionID):\(step.id):\(direction):\(committed)"
        let eventID = pendingSwipeSignature == signature
            ? (pendingSwipeEventID ?? UUID().uuidString) : UUID().uuidString
        pendingSwipeSignature = signature
        pendingSwipeEventID = eventID
        Task {
            defer { isSubmitting = false }
            do {
                let updated = try await BusinessDataService.shared.action(
                    sessionID: practice.sessionID, eventID: eventID,
                    stepID: step.id, planVersion: practice.planVersion,
                    kind: "swipe", direction: direction, committed: committed,
                    visibleMS: visibleMS
                )
                guard !session.isDemoAccount || session.demoRun?.activeSessionID == updated.sessionID else { return }
                session.business.install(session: updated)
                pendingSwipeSignature = nil
                pendingSwipeEventID = nil
                visibleStartedAt = .now
                if updated.currentStepID != step.id { needsExplanation = false }
                if direction == "left", committed,
                   step.id == plan.steps.last?.id {
                    try await finishPractice(sessionID: updated.sessionID)
                }
            } catch {
                await session.handleDemoWriteError(error)
                if DemoRunError.isStale(error) {
                    pendingSwipeSignature = nil
                    pendingSwipeEventID = nil
                    completeRequestID = nil
                }
                errorMessage = error.localizedDescription
            }
        }
    }

    private func requestExplanation(_ step: MakeupPlanStepDTO) {
        guard let practice, !isSubmitting else { return }
        guard !session.isDemoAccount || session.demoRun?.activeSessionID == practice.sessionID else { return }
        isSubmitting = true
        let eventID = pendingExplainStepID == step.id
            ? (pendingExplainEventID ?? UUID().uuidString) : UUID().uuidString
        pendingExplainStepID = step.id
        pendingExplainEventID = eventID
        Task {
            defer { isSubmitting = false }
            do {
                let updated = try await BusinessDataService.shared.action(
                    sessionID: practice.sessionID, eventID: eventID,
                    stepID: step.id, planVersion: practice.planVersion,
                    kind: "explain", direction: nil, committed: nil,
                    visibleMS: visibleDurationMS()
                )
                guard !session.isDemoAccount || session.demoRun?.activeSessionID == updated.sessionID else { return }
                session.business.install(session: updated)
                pendingExplainStepID = nil
                pendingExplainEventID = nil
                visibleStartedAt = .now
            } catch {
                await session.handleDemoWriteError(error)
                if DemoRunError.isStale(error) {
                    pendingExplainStepID = nil
                    pendingExplainEventID = nil
                }
                errorMessage = error.localizedDescription
            }
        }
    }

    private func finishPractice(sessionID: String) async throws {
        guard !session.isDemoAccount || session.demoRun?.activeSessionID == sessionID else {
            throw DemoRunError.stale
        }
        let requestID = completeRequestID ?? UUID().uuidString
        completeRequestID = requestID
        let result = try await BusinessDataService.shared.complete(
            sessionID: sessionID, requestID: requestID
        )
        guard result.growthDelta.levelAfter == result.growthOverview.level else {
            throw APIClientError.invalidResponse
        }
        if session.isDemoAccount { await session.refreshDemoRun() }
        session.business.install(completion: result)
        path.append(AppRoute.makeupComplete)
    }

    private func visibleDurationMS() -> Int {
        Int(max(0, min(Date.now.timeIntervalSince(visibleStartedAt) * 1000, 300_000)))
    }

    private func reportStepExit() {
        guard session.business.completion == nil,
              let practice, let stepID = practice.currentStepID,
              practice.status == "in_progress" else { return }
        guard !session.isDemoAccount || session.demoRun?.activeSessionID == practice.sessionID else { return }
        let visibleMS = visibleDurationMS()
        Task {
            _ = try? await BusinessDataService.shared.action(
                sessionID: practice.sessionID, eventID: UUID().uuidString,
                stepID: stepID, planVersion: practice.planVersion,
                kind: "step_exit", direction: nil, committed: nil,
                visibleMS: visibleMS
            )
        }
    }

    private func loadPortrait(for plan: MakeupPlanDTO) async {
        guard !session.isDemoAccount || session.demoRun?.activePlanID == plan.planID else { return }
        var currentPlan = plan
        for _ in 0..<30 where currentPlan.portrait?.status != "succeeded" {
            guard !Task.isCancelled else { return }
            try? await Task.sleep(for: .seconds(2))
            guard let updated = try? await BusinessDataService.shared.plan(id: plan.planID) else { return }
            currentPlan = updated
        }
        guard let portrait = currentPlan.portrait, portrait.hasAlpha else { return }
        if let data = try? await BusinessDataService.shared.portraitImage(
            id: portrait.portraitID, variant: "full"
        ) {
            if !session.isDemoAccount || session.demoRun?.activePlanID == plan.planID {
                portraitImage = UIImage(data: data)?.croppedToVisibleAlphaBounds()
            }
        }
        for _ in 0..<30 {
            guard !Task.isCancelled else { return }
            guard let updated = try? await BusinessDataService.shared.plan(id: plan.planID) else { return }
            if updated.render.status == "succeeded", let jobID = updated.render.jobID {
                if let result = try? await BusinessDataService.shared.renderResult(jobID: jobID, plan: updated),
                   result.portraitPreview?.status == "succeeded",
                   result.portraitPreview?.sourcePortraitID == portrait.portraitID,
                   let data = try? await BusinessDataService.shared.portraitPreviewImage(jobID: jobID),
                   let image = UIImage(data: data) {
                    if !session.isDemoAccount || session.demoRun?.activePlanID == plan.planID {
                        portraitImage = image.croppedToVisibleAlphaBounds()
                    }
                }
                return
            }
            if updated.render.status == "failed" || updated.render.status == "skipped" { return }
            try? await Task.sleep(for: .seconds(2))
        }
    }
}

private extension UIImage {
    /// Removes transparent canvas padding so cutout portraits fill their assigned UI frame.
    func croppedToVisibleAlphaBounds(alphaThreshold: UInt8 = 8) -> UIImage {
        guard let source = cgImage else { return self }
        let width = source.width
        let height = source.height
        guard width > 0, height > 0 else { return self }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return self }

        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))

        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1
        for y in 0..<height {
            for x in 0..<width where pixels[y * bytesPerRow + x * bytesPerPixel + 3] > alphaThreshold {
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        guard maxX >= minX, maxY >= minY else { return self }
        let padding = max(2, min(width, height) / 100)
        let cropRect = CGRect(
            x: max(0, minX - padding),
            y: max(0, minY - padding),
            width: min(width - max(0, minX - padding), maxX - minX + 1 + padding * 2),
            height: min(height - max(0, minY - padding), maxY - minY + 1 + padding * 2)
        )
        guard let cropped = source.cropping(to: cropRect) else { return self }
        return UIImage(cgImage: cropped, scale: scale, orientation: imageOrientation)
    }
}

#Preview {
    NavigationStack {
        MakeupStepsView(session: AppSession(), path: .constant(NavigationPath()))
    }
}
