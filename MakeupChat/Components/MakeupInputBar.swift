import SwiftUI

struct MakeupInputBar: View {
    @Binding var text: String
    var onSend: () -> Void
    var isSending = false
    var initialFocus = false

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
            iconButton("plus", size: 30)
            iconButton("camera", size: 28)
                .padding(.leading, 4)

            TextField("来探寻今日的妆容灵感", text: $text)
                .focused($isFocused)
                .font(.system(size: 12, weight: .light))
                .foregroundStyle(Color(red: 0.4, green: 0.4, blue: 0.4))
                .keyboardType(.default)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .submitLabel(.send)
                .onSubmit(sendIfPossible)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .contentShape(Capsule())
                .background {
                    Capsule()
                        .fill(Color.white)
                }
                .clipShape(Capsule())
                .frame(width: 260, height: 36)
                .padding(.horizontal, 8)
                .accessibilityLabel("对话输入框")
                .accessibilityHint("轻点后使用系统键盘输入消息")

            Button(action: sendIfPossible) {
                Image(systemName: "arrow.up.circle")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(Color(red: 0.3, green: 0.3, blue: 0.3))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .disabled(isSending || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .onAppear {
            if initialFocus { isFocused = true }
        }
    }

    private func sendIfPossible() {
        guard !isSending, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        onSend()
    }

    private func iconButton(_ systemName: String, size: CGFloat) -> some View {
        Button(action: {}) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.55))
                .foregroundStyle(Color(red: 0.3, green: 0.3, blue: 0.3))
                .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .disabled(true)
        .accessibilityLabel("本阶段暂不支持图片对话")
    }
}
