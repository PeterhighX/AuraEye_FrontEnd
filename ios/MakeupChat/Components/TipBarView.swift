import SwiftUI

struct TipBarView: View {
    let tipText: String

    var body: some View {
        HStack(spacing: 0) {
            Text("小知识")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(.white)
                .tracking(1)
                .frame(width: 64)
                .padding(.vertical, 4)
                .background(Color(red: 0.15, green: 0.15, blue: 0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Text(tipText)
                .font(.system(size: 12, weight: .thin))
                .foregroundStyle(Color(red: 0.15, green: 0.15, blue: 0.15))
                .tracking(1)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.24))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(.horizontal, 16)
    }
}
