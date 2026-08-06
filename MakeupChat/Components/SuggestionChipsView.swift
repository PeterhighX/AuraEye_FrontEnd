import SwiftUI

struct SuggestionChipsView: View {
    var onSelect: (String) -> Void

    var body: some View {
        HStack(spacing: 8) {
            chip(systemName: "leaf", title: "我想要更清新") {
                onSelect("我想要更清新")
            }
            chip(systemName: "doc.text", title: "我想要正式一点") {
                onSelect("我想要正式一点")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 16)
    }

    private func chip(systemName: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemName)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(red: 0.15, green: 0.15, blue: 0.15))
                Text(title)
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(Color(red: 0.15, green: 0.15, blue: 0.15))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color(red: 0.3, green: 0.3, blue: 0.3, opacity: 0.09), radius: 2, y: 2)
        }
        .buttonStyle(.plain)
    }
}
