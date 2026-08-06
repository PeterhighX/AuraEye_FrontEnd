import SwiftUI

/// Figma 20:1113 / 20:1178 — 带阻力的整页卡片式上妆步骤
struct MakeupStepsView: View {
    @Bindable var session: AppSession
    @Binding var path: NavigationPath
    @Environment(\.dismiss) private var dismiss

    @State private var currentStep = 0
    @State private var horizontalDrag: CGFloat = 0
    @State private var needsExplanation = false
    @State private var explanationText: String?
    @State private var isLoadingExplanation = false
    @State private var isPaging = false

    private let explanationService: any MakeupExplanationServicing = LocalMakeupExplanationService()

    private var plan: MakeupLookPlan {
        MakeupLookCatalog.plan(id: session.selectedLookID)
    }

    private var activeStep: MakeupInstructionStep {
        plan.steps[currentStep]
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                MakeupFlowHeaderView(title: "上妆步骤", usesPreviewAssets: true) {
                    dismiss()
                }
                .padding(.top, 8)

                progressCard
                    .padding(.top, 24)

                stepPreview
                    .padding(.top, 24)

                resistantPager
                    .id("practice-pager-\(plan.id)")
                    .frame(height: 422)
                    .padding(.top, 20)

                assistantTip
                    .padding(.top, 4)

                Spacer(minLength: 8)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .animation(AppTheme.Motion.stepSpring, value: currentStep)
    }

    private var progressCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Step \(currentStep + 1)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 92, height: 32)
                        .background(
                            AppTheme.ColorToken.textPrimary,
                            in: RoundedRectangle(cornerRadius: 12)
                        )

                    Text(activeStep.title)
                        .font(.title3)
                        .fontDesign(.rounded)
                }

                ProgressView(
                    value: Double(currentStep + 1),
                    total: Double(plan.steps.count)
                )
                .tint(AppTheme.ColorToken.accentCoral)

                HStack {
                    Text("\((currentStep + 1) * 20)%")
                    Spacer()
                    Text(currentStep == plan.steps.count - 1 ? "完成后继续左划" : "加油哦")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Image("AvatarUser")
                .resizable()
                .scaledToFill()
                .frame(width: 88, height: 116)
                .offset(y: 10)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("用户头像")
        }
        .padding(.horizontal, 16)
        .frame(height: 103)
        .background(
            Color(red: 1, green: 237 / 255, blue: 232 / 255).opacity(0.4),
            in: RoundedRectangle(cornerRadius: 24)
        )
        .shadow(color: .black.opacity(0.08), radius: 3, y: 2)
        .padding(.horizontal, 16)
    }

    private var stepPreview: some View {
        Image(activeStep.previewAsset)
            .resizable()
            .scaledToFill()
            .frame(width: 320, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .contentTransition(.opacity)
            .accessibilityLabel("第 \(currentStep + 1) 步眼部线条预览")
    }

    private var resistantPager: some View {
        GeometryReader { proxy in
            let cardWidth = min(CGFloat(270), proxy.size.width - 96)
            let pageStride = cardWidth + 24

            HStack(spacing: 24) {
                ForEach(Array(plan.steps.enumerated()), id: \.element.id) { index, step in
                    tutorialCard(for: step)
                        .frame(width: cardWidth)
                        .scaleEffect(index == currentStep ? 1 : 0.94)
                        .blur(radius: index == currentStep ? 0 : 7)
                        .opacity(index == currentStep ? 1 : 0.42)
                        .accessibilityHidden(index != currentStep)
                }
            }
            .offset(
                x: (proxy.size.width - cardWidth) / 2
                    - CGFloat(currentStep) * pageStride
                    + horizontalDrag
            )
            .contentShape(Rectangle())
            .gesture(pagerGesture)
            .animation(
                .spring(response: 0.52, dampingFraction: 0.88),
                value: currentStep
            )
        }
        .clipped()
    }

    private var pagerGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard !isPaging else { return }
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                // Deliberate resistance: the card moves less than the finger.
                horizontalDrag = value.translation.width * 0.38
            }
            .onEnded { value in
                guard !isPaging else { return }
                if abs(value.translation.height) > abs(value.translation.width) {
                    if value.translation.height < -60 {
                        withAnimation(.easeOut(duration: 0.2)) {
                            needsExplanation = true
                        }
                    } else if value.translation.height > 60 {
                        withAnimation(.easeOut(duration: 0.2)) {
                            resetExplanation()
                        }
                    }
                    horizontalDrag = 0
                    return
                }

                // 必须把手指确实拖到接近整张卡片的尽头；快速轻扫不提交。
                // 未达到阈值时通过弹簧动画回到当前卡片。
                let committedLeft = value.translation.width < -230
                let committedRight = value.translation.width > 230

                if committedLeft {
                    commitPage(direction: 1)
                } else if committedRight, currentStep > 0 {
                    commitPage(direction: -1)
                } else {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) {
                        horizontalDrag = 0
                    }
                }
            }

    }

    private func tutorialCard(for step: MakeupInstructionStep) -> some View {
        let showsExplanation = needsExplanation && step.id == activeStep.id

        return VStack(spacing: 0) {
            VStack(spacing: 22) {
                HStack {
                    Text("当前工具")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(step.tool)
                        .font(.headline)
                        .underline()
                }

                Image("EyelinerProductIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 112, height: 112)
                    .accessibilityLabel(step.tool)

                styledMakeupInstruction(step.instruction)
                    .font(.callout)
                    .fontWeight(.light)
                    .foregroundStyle(AppTheme.ColorToken.textSecondary)
                    .tracking(1)
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 22)
            .frame(height: 360, alignment: .top)
            .blur(radius: showsExplanation ? 1.8 : 0)

            if showsExplanation {
                explanationFooter(for: step)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(height: showsExplanation ? 410 : 360, alignment: .top)
        .background(.white.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }

    private func explanationFooter(for step: MakeupInstructionStep) -> some View {
        Group {
            if let explanationText {
                Text(explanationText)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
            } else {
                Button {
                    requestExplanation(for: step)
                } label: {
                    if isLoadingExplanation {
                        ProgressView().tint(.white)
                    } else {
                        Text("需要讲解")
                    }
                }
                .font(.callout)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 50)
        .background(Color(red: 1.0, green: 92 / 255, blue: 92 / 255).opacity(0.72))
    }

    private var assistantTip: some View {
        HStack(spacing: 10) {
            Image("FirstTimeAssistant")
                .resizable()
                .scaledToFill()
                .frame(width: 36, height: 36)
                .clipShape(Circle())

            Text("小提示：\(activeStep.tip)")
                .font(.system(size: 12, weight: .thin))
                .fontWeight(.thin)
                .foregroundStyle(Color(red: 51 / 255, green: 51 / 255, blue: 51 / 255))
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
                .minimumScaleFactor(0.88)
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(.white.opacity(0.75))
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
    }

    private func requestExplanation(for step: MakeupInstructionStep) {
        guard !isLoadingExplanation else { return }
        isLoadingExplanation = true
        Task { @MainActor in
            defer { isLoadingExplanation = false }
            explanationText = try? await explanationService.explain(
                stepTitle: step.title,
                instruction: step.instruction
            )
        }
    }

    private func resetExplanation() {
        needsExplanation = false
        explanationText = nil
        isLoadingExplanation = false
    }

    private func commitPage(direction: Int) {
        guard !isPaging else { return }
        isPaging = true
        let screenWidth = UIScreen.main.bounds.width
        let exitOffset = direction > 0 ? -screenWidth : screenWidth

        withAnimation(.easeIn(duration: 0.24)) {
            horizontalDrag = exitOffset
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))

            if direction > 0, currentStep == plan.steps.count - 1 {
                horizontalDrag = 0
                isPaging = false
                path.append(AppRoute.makeupComplete)
                return
            }

            currentStep += direction
            resetExplanation()
            horizontalDrag = direction > 0 ? screenWidth : -screenWidth

            withAnimation(.spring(response: 0.48, dampingFraction: 0.9)) {
                horizontalDrag = 0
            }

            try? await Task.sleep(for: .milliseconds(480))
            isPaging = false
        }
    }
}

#Preview {
    NavigationStack {
        MakeupStepsView(session: AppSession(), path: .constant(NavigationPath()))
    }
}
