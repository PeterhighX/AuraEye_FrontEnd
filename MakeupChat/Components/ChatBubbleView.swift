import SwiftUI
import UIKit

struct ChatBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.sender == .ai {
                avatarImage(message.aiAvatarName)
                bubbleContent
                Color.clear.frame(width: 36, height: 36)
            } else {
                Color.clear.frame(width: 36, height: 36)
                bubbleContent
                avatarImage("AvatarUserMsg")
            }
        }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if message.sender == .ai, message.text.contains("Mrs Zhang") {
                (
                    Text("Mrs Zhang").font(.system(size: 14, weight: .regular, design: .rounded))
                    + Text("，请给我一张图片帮你生成今日的妆容")
                        .font(.system(size: 14, weight: .thin))
                )
                .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.2))
                .lineSpacing(4)
            } else {
                Text(message.text)
                    .font(.system(size: 14, weight: .thin))
                    .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.2))
                    .lineSpacing(4)
            }

            if let imageName = message.imageName {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 177, height: 177)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if message.imagePath != nil {
                LocalImageView(storedPath: message.imagePath, systemImage: "photo")
                    .frame(width: 177, height: 177)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal, message.sender == .user ? 9 : 12)
        .padding(.vertical, message.sender == .user ? 7 : 8)
        .frame(maxWidth: 274, alignment: .leading)
        .background(bubbleBackground)
        .clipShape(bubbleShape)
    }

    private var bubbleBackground: some View {
        Group {
            if message.sender == .user {
                Color(red: 0.88, green: 0.88, blue: 1.0)
            } else {
                Color.white.opacity(0.75)
            }
        }
    }

    private var bubbleShape: UnevenRoundedRectangle {
        if message.sender == .user {
            UnevenRoundedRectangle(
                topLeadingRadius: 13,
                bottomLeadingRadius: 13,
                bottomTrailingRadius: 13,
                topTrailingRadius: 0
            )
        } else {
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 13,
                bottomTrailingRadius: 13,
                topTrailingRadius: 13
            )
        }
    }

    private func avatarImage(_ name: String) -> some View {
        Image(name)
            .resizable()
            .scaledToFill()
            .frame(width: 36, height: 36)
            .clipShape(Circle())
    }
}
