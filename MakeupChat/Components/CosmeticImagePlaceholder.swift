import SwiftUI

/// 产品图占位 — 后台识别接入后再显示真实拍摄图
struct CosmeticImagePlaceholder: View {
    let category: CosmeticCategory

    var body: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(Color(red: 0.89, green: 0.89, blue: 0.88))
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                Image(systemName: category.placeholderSymbol)
                    .font(.system(size: 28))
                    .foregroundStyle(Color.white.opacity(0.9))
            }
    }
}

struct CosmeticColorSwatches: View {
    let hexes: [String]

    var body: some View {
        HStack(spacing: 8) {
            if hexes.isEmpty {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(Color(red: 0.85, green: 0.85, blue: 0.85))
                        .frame(width: 20, height: 20)
                }
            } else {
                ForEach(hexes.prefix(5), id: \.self) { hex in
                    Circle()
                        .fill(Color(hex: hex) ?? Color.gray.opacity(0.4))
                        .frame(width: 20, height: 20)
                }
            }
        }
        .frame(height: 28)
    }
}

private extension Color {
    init?(hex: String) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitized.hasPrefix("#") { sanitized.removeFirst() }
        guard sanitized.count == 6, let value = UInt64(sanitized, radix: 16) else { return nil }

        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
