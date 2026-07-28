import SwiftUI

struct MakeupFlowHeaderView: View {
    let title: String
    var usesPreviewAssets = false
    var onBack: (() -> Void)?

    var body: some View {
        HStack(spacing: 0) {
            Button {
                onBack?()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Color(red: 0.15, green: 0.15, blue: 0.15))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("返回")

            Text(title)
                .font(.system(size: 24, weight: .regular, design: .rounded))
                .foregroundStyle(Color(red: 0.15, green: 0.15, blue: 0.15).opacity(0.8))
                .frame(height: 30)
                .padding(.leading, 8)

            Spacer()

            HStack(spacing: 8) {
                if usesPreviewAssets {
                    assetIconButton(name: "PreviewAssistant", label: "智能提示")
                    assetIconButton(name: "PreviewMenu", label: "菜单")
                } else {
                    iconButton(systemName: "sparkles", label: "智能提示")
                    iconButton(systemName: "line.3.horizontal", label: "菜单")
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(Color.clear)
    }

    private func assetIconButton(name: String, label: String) -> some View {
        Button(action: { /* TODO: 接入对应操作 */ }) {
            Image(name)
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func iconButton(systemName: String, label: String) -> some View {
        Button(action: { /* TODO: 接入对应操作 */ }) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(red: 0.15, green: 0.15, blue: 0.15))
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.borderless)
        .buttonBorderShape(.circle)
        .background(Color.white.opacity(0.35), in: Circle())
        .accessibilityLabel(label)
    }
}
