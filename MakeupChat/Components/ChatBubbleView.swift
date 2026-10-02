import SwiftUI
import UIKit

struct ChatBubbleView: View {
    let message: ChatMessage
    var onRetry: (() -> Void)?
    var onRetryAttachment: ((ChatAttachment) -> Void)?
    var onOpenAttachment: ((ChatAttachment) -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.sender == .ai {
                agentAvatar
                bubbleContent
                Color.clear.frame(width: 36, height: 36)
            } else {
                Color.clear.frame(width: 36, height: 36)
                bubbleContent
                userAvatar
            }
        }
    }

    private var bubbleContent: some View {
        VStack(alignment: .leading, spacing: 7) {
            if message.sender == .ai,
               message.deliveryStatus == .streaming,
               message.text.isEmpty {
                HStack(spacing: 7) {
                    ProgressView().controlSize(.small)
                    Text("正在思考…")
                }
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary)
            } else {
                ForEach(message.attachments) { attachment in
                    attachmentView(attachment)
                }

                if !message.text.isEmpty {
                    Text(message.text)
                        .font(.system(size: 16, weight: .thin))
                        .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.2))
                        .lineSpacing(4)
                }
            }

            if message.sender == .user {
                deliveryStatus
            }
        }
        .padding(.horizontal, message.sender == .user ? 9 : 12)
        .padding(.vertical, message.sender == .user ? 7 : 8)
        .frame(maxWidth: 274, alignment: .leading)
        .background(message.sender == .user ? Color(red: 0.88, green: 0.88, blue: 1.0) : Color.white.opacity(0.75))
        .clipShape(bubbleShape)
    }

    @ViewBuilder
    private func attachmentView(_ attachment: ChatAttachment) -> some View {
        let height = min(280, max(120, 238 * CGFloat(attachment.height) / CGFloat(attachment.width)))
        if let image = LocalMediaStore.loadImage(fromStoredPath: attachment.localThumbnailPath)
            ?? LocalMediaStore.loadImage(fromStoredPath: attachment.localContentPath) {
            Button {
                onOpenAttachment?(attachment)
            } label: {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 238, height: height)
                    .clipped()
            }
            .buttonStyle(.plain)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            VStack(spacing: 9) {
                Image(systemName: "photo.badge.arrow.down")
                    .font(.title2)
                Button("重新加载图片") {
                    onRetryAttachment?(attachment)
                }
                .buttonStyle(.borderless)
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .frame(width: 238, height: height)
            .background(.white.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    @ViewBuilder
    private var deliveryStatus: some View {
        Group {
            switch message.deliveryStatus {
            case .sending:
                Label("发送中", systemImage: "clock")
                    .foregroundStyle(.secondary)
            case .streaming:
                EmptyView()
            case .completed:
                EmptyView()
            case .failedRetryable, .failedPermanent:
                VStack(alignment: .leading, spacing: 3) {
                    Text(diagnosticText)
                    if message.deliveryStatus.isRetryable, let onRetry {
                        Button("重试", action: onRetry)
                            .buttonStyle(.borderless)
                    }
                }
                .foregroundStyle(Color.red.opacity(0.8))
            }
        }
        .font(.system(size: 11, weight: .regular))
    }

    private var diagnosticText: String {
        let status = message.httpStatus.map { "HTTP \($0)" }
        let code = message.errorCode
        let request = message.serverRequestId.map { "请求 \($0.prefix(12))…" }
        return [status, code, request].compactMap { $0 }.joined(separator: " · ")
            .ifEmpty(message.errorDetail ?? "发送失败")
    }

    private var bubbleShape: UnevenRoundedRectangle {
        message.sender == .user
            ? UnevenRoundedRectangle(topLeadingRadius: 13, bottomLeadingRadius: 13, bottomTrailingRadius: 13, topTrailingRadius: 0)
            : UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 13, bottomTrailingRadius: 13, topTrailingRadius: 13)
    }

    private var agentAvatar: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.9))
            Image("AgentHead")
                .resizable()
                .scaledToFill()
        }
        .frame(width: 36, height: 36)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.95), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
    }

    private var userAvatar: some View {
        Group {
            if let data = BusinessStore.shared.avatarData,
               let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable().scaledToFill().foregroundStyle(.secondary)
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(Circle())
    }
}

private extension String {
    func ifEmpty(_ fallback: @autoclosure () -> String) -> String { isEmpty ? fallback() : self }
}
