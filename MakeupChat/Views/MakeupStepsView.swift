import SwiftUI

/// Figma 20:1113 / 20:1178 — 卡片式上妆步骤
struct MakeupStepsView: View {
    @Bindable var session: AppSession
    @Binding var path: NavigationPath
    @Environment(\.dismiss) private var dismiss

    @State private var currentStep = 0
    @State private var needsExplanation = false
    @State private var explanationText: String?
    @State private var isLoadingExplanation = false
    private let explanationService: any MakeupExplanationServicing = LocalMakeupExplanationService()

    private let steps = [
        MakeupTutorialStep(
            title: "铺设底妆",
            tool: "大号铺色刷",
            symbol: "eye",
            instruction: "咱们先保持眼部干燥，拿一把【大号铺色刷】沾取【哑光蜜桃粉肉色】，在整个上眼皮大面积铺色打底。手法一定要轻，少量多次地【叠加】，把眼皮上的暗沉和油脂都盖住。"
        ),
        MakeupTutorialStep(
            title: "修容&阴影",
            tool: "晕染刷",
            symbol: "paintbrush.pointed.fill",
            instruction: "从眼窝外侧向内轻轻晕染，用少量阴影色塑造自然轮廓，边缘要柔和。"
        ),
        MakeupTutorialStep(
            title: "眼睑下至",
            tool: "细节刷",
            symbol: "pencil.tip",
            instruction: "沿下眼睑后半段少量叠加颜色，并和上眼影自然连接。"
        ),
        MakeupTutorialStep(
            title: "卧蚕",
            tool: "小号细节刷",
            symbol: "wand.and.stars",
            instruction: "在卧蚕高点轻扫提亮色，阴影线保持纤细自然。"
        ),
        MakeupTutorialStep(
            title: "完成定妆",
            tool: "定妆刷",
            symbol: "checkmark.seal.fill",
            instruction: "检查两侧眼妆是否对称，轻扫余粉，让妆面保持干净。"
        )
    ]

    var body: some View {
        ZStack {
            MakeupPracticeBackgroundView()

            VStack(spacing: 0) {
                MakeupFlowHeaderView(title: "上妆步骤", usesPreviewAssets: true) {
                    dismiss()
                }
                .padding(.top, 8)

                VStack(spacing: 0) {
                    progressCard
                        .padding(.top, 24)

                    eyePreview
                        .padding(.top, 24)

                    TabView(selection: $currentStep) {
                        ForEach(steps.indices, id: \.self) { index in
                            tutorialCard(for: steps[index])
                                .tag(index)
                                .padding(.horizontal, 66)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: 422)
                    .padding(.top, 24)
                    .onChange(of: currentStep) { _, _ in
                        needsExplanation = false
                        explanationText = nil
                    }

                    HStack(spacing: 10) {
                        Image("AvatarAI")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                        Text("小提示：注意边缘晕染自然哦~")
                            .font(.system(size: 14, weight: .thin))
                            .foregroundStyle(Color(red: 51 / 255, green: 51 / 255, blue: 51 / 255))
                            .frame(maxWidth: .infinity, alignment: .leading)
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

                Spacer(minLength: 8)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .animation(AppTheme.Motion.stepSpring, value: currentStep)
    }

    private var activeStep: MakeupTutorialStep {
        steps[currentStep]
    }

    private var progressCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Step \(currentStep + 1)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 92, height: 32)
                        .background(
                            Color(red: 38 / 255, green: 38 / 255, blue: 38 / 255),
                            in: RoundedRectangle(cornerRadius: 12)
                        )

                    Text(activeStep.title)
                        .font(.system(size: 20, weight: .regular, design: .rounded))
                        .foregroundStyle(AppTheme.ColorToken.textPrimary)
                }

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.75))
                        .frame(height: 8)
                    Capsule()
                        .fill(Color(red: 253 / 255, green: 124 / 255, blue: 84 / 255).opacity(0.75))
                        .frame(width: CGFloat(currentStep + 1) / CGFloat(steps.count) * 206, height: 8)
                }

                HStack {
                    Text("\((currentStep + 1) * 20)%")
                    Spacer()
                    Text(currentStep == steps.count - 1 ? "最后一步" : "加油哦")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Image("AvatarUser")
                .resizable()
                .scaledToFill()
                .frame(width: 73, height: 98)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("用户头像")
        }
        .padding(.horizontal, 16)
        .frame(height: 103)
        .background(Color(red: 1, green: 237 / 255, blue: 232 / 255).opacity(0.4), in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.08), radius: 3, y: 2)
        .padding(.horizontal, 16)
    }

    private var eyePreview: some View {
        ZStack {
            Image("StepEyes")
                .resizable()
                .scaledToFill()
                .frame(width: 320, height: 444)
                .offset(y: -133)

            HStack(spacing: 72) {
                dashedEyeGuide
                dashedEyeGuide
            }
        }
        .frame(width: 320, height: 90)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .accessibilityLabel("眼部上妆区域示意")
    }

    private var dashedEyeGuide: some View {
        Capsule()
            .trim(from: 0.05, to: 0.92)
            .stroke(.white, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 4]))
            .frame(width: 58, height: 22)
    }

    private func tutorialCard(for step: MakeupTutorialStep) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 24) {
                HStack {
                    Text("当前工具")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(step.tool)
                        .font(.headline)
                        .underline()
                }

                Image("StepTool")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)

                Text(step.instruction)
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(Color(red: 38 / 255, green: 38 / 255, blue: 38 / 255).opacity(0.75))
                    .tracking(1)
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 22)
            .frame(height: 360)
            .contentShape(Rectangle())
            .blur(radius: needsExplanation ? 2.3 : 0)
            .onTapGesture {
                withAnimation(.easeOut(duration: 0.2)) {
                    needsExplanation = true
                }
            }

            if needsExplanation {
                VStack(spacing: 8) {
                    if let explanationText {
                        Text(explanationText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                    }
                }
                .background(Color(red: 1.0, green: 92 / 255, blue: 92 / 255).opacity(0.72))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(width: 270, height: needsExplanation ? 400 : 360, alignment: .top)
        .background(.white.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        .onTapGesture {
            guard !needsExplanation else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                needsExplanation = true
            }
        }
    }

    private func requestExplanation(for step: MakeupTutorialStep) {
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

    private func advanceStep() {
        if currentStep < steps.count - 1 {
            currentStep += 1
            needsExplanation = false
        } else {
            path.append(AppRoute.makeupComplete)
        }
    }
}

private struct MakeupTutorialStep {
    let title: String
    let tool: String
    let symbol: String
    let instruction: String
}

#Preview {
    NavigationStack {
        MakeupStepsView(session: AppSession(), path: .constant(NavigationPath()))
    }
}
