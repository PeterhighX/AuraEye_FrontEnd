import SwiftUI
import UIKit

struct ChatConversationView: View {
    enum LayoutMode {
        case full
        case keyboard
    }

    @Bindable var viewModel: ChatViewModel
    let layoutMode: LayoutMode
    var onBack: () -> Void = {}
    var onMakeupReady: () -> Void = {}

    @FocusState private var isInputFocused: Bool
    @State private var showImagePicker = false
    @State private var showImageSourcePicker = false
    @State private var imageSource: UIImagePickerController.SourceType = .camera
    @State private var generatedImageReveal = false
    @State private var isGenerationFinished = false
    @State private var assistantCountWhenOpeningPicker = 0

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                VStack(spacing: 24) {
                    ProfileHeaderView(user: viewModel.user, onBack: onBack)
                    TipBarView()
                }
                .padding(.top, 8)

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 18) {
                            ForEach(viewModel.messages) { message in
                                if message.kind == .generating {
                                    generatingRow(message: message)
                                        .id(message.id)
                                } else {
                                    ChatBubbleView(message: message)
                                        .id(message.id)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, layoutMode == .full ? 120 : 24)
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        if let last = viewModel.messages.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }

                            // 小助手的回复已经加入对话后，结束文本输入并收起系统键盘。
                            if last.sender == .ai {
                                isInputFocused = false
                            }
                        }
                    }
                    .onChange(of: isInputFocused) { _, isFocused in
                        guard isFocused, let last = viewModel.messages.last else { return }

                        Task { @MainActor in
                            // 等待系统键盘开始改变安全区，再把末条内容滚到输入栏上方。
                            try? await Task.sleep(for: .milliseconds(180))
                            withAnimation(.easeOut(duration: 0.28)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
                .frame(maxHeight: layoutMode == .keyboard ? .infinity : nil, alignment: .bottom)

                if layoutMode == .full {
                    Spacer(minLength: 0)
                }
            }

            if layoutMode == .full && !isInputFocused {
                VStack {
                    Spacer()
                    SuggestionChipsView { suggestion in
                        viewModel.sendSuggestion(suggestion)
                    }
                    // safeAreaInset 已将内容底边推到输入框上方；
                    // 此处只留 4pt，使建议按钮紧贴输入框。
                    .padding(.bottom, 4)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            inputBar
                .background {
                    Rectangle()
                        .fill(isInputFocused ? AnyShapeStyle(Color.clear) : AnyShapeStyle(.ultraThinMaterial))
                        .ignoresSafeArea(edges: .bottom)
                }
        }
        .animation(.easeOut(duration: 0.18), value: isInputFocused)
        .onAppear {
            viewModel.reload()
            // 普通负一屏等待用户点击输入框；键盘态预览直接显示系统键盘。
            isInputFocused = layoutMode == .keyboard
        }
        .onChange(of: showImagePicker) { _, isPresented in
            if !isPresented {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    let currentAssistantCount = viewModel.messages.lazy
                        .filter { $0.sender == .ai }
                        .count
                    // 取消选择时恢复输入；若选图后小助手已经作答，则保持键盘收起。
                    isInputFocused = currentAssistantCount == assistantCountWhenOpeningPicker
                }
            }
        }
        .onChange(of: viewModel.isMakeupReady) { _, isReady in
            if isReady {
                onMakeupReady()
            }
        }
        .fullScreenCover(isPresented: $showImagePicker) {
            CameraPickerView(
                onImageCaptured: viewModel.uploadPhoto,
                sourceType: imageSource,
                cameraDevice: .rear
            )
        }
        .overlay {
            if showImageSourcePicker {
                MediaSourceDialog(
                    onCamera: {
                        imageSource = .camera
                        showImageSourcePicker = false
                        showImagePicker = true
                    },
                    onLibrary: {
                        imageSource = .photoLibrary
                        showImageSourcePicker = false
                        showImagePicker = true
                    },
                    onCancel: {
                        showImageSourcePicker = false
                        restoreInputFocus()
                    }
                )
            }
        }
    }

    private var inputBar: some View {
        MakeupInputBar(
            text: $viewModel.inputText,
            focusBinding: $isInputFocused,
            onSend: { viewModel.sendMessage() },
            onCamera: {
                isInputFocused = false
                assistantCountWhenOpeningPicker = viewModel.messages.lazy
                    .filter { $0.sender == .ai }
                    .count
                showImageSourcePicker = true
            },
            onUpload: {
                isInputFocused = false
                assistantCountWhenOpeningPicker = viewModel.messages.lazy
                    .filter { $0.sender == .ai }
                    .count
                showImageSourcePicker = true
            },
            isKeyboardPresented: isInputFocused
        )
    }

    private func restoreInputFocus() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isInputFocused = true
        }
    }

    private func generatingRow(message: ChatMessage) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image("FirstTimeAssistant")
                .resizable()
                .scaledToFill()
                .frame(width: 36, height: 36)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 10) {
                Text(message.text)
                    .font(.system(size: 14, weight: .thin))
                    .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.2))
                    .lineSpacing(4)

                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.94, green: 0.94, blue: 0.94))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        if let imageName = message.imageName {
                            Image(imageName)
                                .resizable()
                                .scaledToFill()
                                .scaleEffect(1.1)
                                .opacity(generatedImageReveal ? 1 : 0)
                                .blur(radius: generatedImageReveal ? 0 : 10)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else if let imagePath = message.imagePath {
                            LocalImageView(storedPath: imagePath)
                                .scaledToFill()
                                .scaleEffect(1.1)
                                .opacity(generatedImageReveal ? 1 : 0)
                                .blur(radius: generatedImageReveal ? 0 : 10)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .overlay {
                        if !isGenerationFinished {
                            ProgressView()
                                .tint(AppTheme.ColorToken.accentCoral)
                        }
                    }
                    .task(id: message.id) {
                        generatedImageReveal = false
                        isGenerationFinished = false
                        try? await Task.sleep(for: .seconds(3))
                        guard !Task.isCancelled else { return }
                        isGenerationFinished = true
                        withAnimation(.easeInOut(duration: 0.48)) {
                            generatedImageReveal = true
                        }
                    }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: 274, alignment: .leading)
            .background(Color.white.opacity(0.75))
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 13,
                    bottomTrailingRadius: 13,
                    topTrailingRadius: 13
                )
            )

            Color.clear.frame(width: 36, height: 36)
        }
    }
}
