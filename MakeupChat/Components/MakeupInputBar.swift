import SwiftUI

struct MakeupInputBar: View {
    @Binding var text: String
    var focusBinding: FocusState<Bool>.Binding
    var onSend: () -> Void
    var onCamera: () -> Void
    var onUpload: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            iconButton("plus", size: 30, action: onUpload)
            iconButton("camera", size: 28, action: onCamera)
                .padding(.leading, 4)

            TextField("来探寻今日的妆容灵感", text: $text)
                .font(.system(size: 12, weight: .light))
                .foregroundStyle(Color(red: 0.4, green: 0.4, blue: 0.4))
                .focused(focusBinding)
                .submitLabel(.send)
                .onSubmit(onSend)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(.white)
                .clipShape(Capsule())
                .frame(width: 260)
                .padding(.horizontal, 8)

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(Color(red: 0.3, green: 0.3, blue: 0.3))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func iconButton(_ systemName: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.55))
                .foregroundStyle(Color(red: 0.3, green: 0.3, blue: 0.3))
                .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
    }
}
