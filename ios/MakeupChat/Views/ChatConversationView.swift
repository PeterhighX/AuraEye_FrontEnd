import SwiftUI

struct ChatConversationView: View {
    enum LayoutMode {
        case full
        case keyboard
    }

    @Bindable var viewModel: ChatViewModel
    let layoutMode: LayoutMode

    @FocusState private var isInputFocused: Bool

    var body: some View {
        ZStack {
            GradientBackgroundView()

            VStack(spacing: 0) {
                VStack(spacing: 24) {
                    ProfileHeaderView(user: viewModel.user)
                    TipBarView(tipText: viewModel.tipText)
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
                        }
                    }
                }
                .frame(maxHeight: layoutMode == .keyboard ? .infinity : nil, alignment: .bottom)

                if layoutMode == .full {
                    Spacer(minLength: 0)
                }
            }

            if layoutMode == .full {
                VStack {
                    Spacer()
                    dailyCTA
                        .padding(.bottom, 180)
                }

                VStack {
                    Spacer()
                    SuggestionChipsView { suggestion in
                        viewModel.sendSuggestion(suggestion)
                    }
                    .padding(.bottom, 68)
                }

                VStack {
                    Spacer()
                    inputBar
                        .background(.ultraThinMaterial.opacity(0.01))
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if layoutMode == .keyboard {
                inputBar
                    .background(.ultraThinMaterial)
            }
        }
        .onAppear {
            viewModel.reload()
            if layoutMode == .keyboard {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isInputFocused = true
                }
            }
        }
    }

    private var inputBar: some View {
        MakeupInputBar(
            text: $viewModel.inputText,
            focusBinding: $isInputFocused,
            onSend: { viewModel.sendMessage() },
            onCamera: { viewModel.uploadDemoPhoto() },
            onUpload: { viewModel.uploadDemoPhoto() }
        )
    }

    private var dailyCTA: some View {
        Button {
            viewModel.uploadDemoPhoto()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.2))
                Text("快来使用每日一拍吧")
                    .font(.system(size: 16, weight: .light))
                    .tracking(1)
                    .foregroundStyle(.black)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
    }

    private func generatingRow(message: ChatMessage) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(message.aiAvatarName)
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
