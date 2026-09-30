import SwiftUI
import UIKit

struct CosmeticProductCard: View {
    let item: CosmeticDTO
    let category: CosmeticCategory
    @State private var productImageData: Data?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            productImage

            Text(item.displayName)
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(.black)
                .lineLimit(1)

            if category == .eyeshadow {
                tagPill(item.shade ?? item.tags.first ?? "色系待补充")
                CosmeticColorSwatches(hexes: item.colorHexes)
            } else {
                tagPill(item.material ?? "材质待补充")
                Text(item.summary ?? "商品信息待补充")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(8)
        .frame(width: 156)
        .background(Color(red: 0.98, green: 0.98, blue: 0.98))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .task(id: "\(SessionManager.shared.context?.userId ?? ""):\(item.id)") {
            productImageData = nil
            guard item.hasImage, let accountID = SessionManager.shared.context?.userId else { return }
            let data = try? await BusinessDataService.shared.cosmeticImage(id: item.id)
            guard SessionManager.shared.context?.userId == accountID else { return }
            productImageData = data
        }
    }

    private var productImage: some View {
        Group {
            if let data = productImageData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                CosmeticImagePlaceholder(category: category)
            }
        }
        .frame(width: 140, height: 140)
        .clipped()
        .background(Color(red: 0.89, green: 0.89, blue: 0.88))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func tagPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .light))
            .foregroundStyle(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 2)
            .background(Color.white)
            .clipShape(Capsule())
    }
}

private extension CosmeticDTO {
    var tags: [String] {
        guard case .array(let values)? = attributes?["tags"] else { return [] }
        return values.compactMap { if case .string(let text) = $0 { return text }; return nil }
    }

    var colorHexes: [String] {
        guard case .array(let values)? = attributes?["color_hexes"] else { return [] }
        return values.compactMap { if case .string(let text) = $0 { return text }; return nil }
    }

    var material: String? {
        guard case .string(let text)? = attributes?["material"] else { return nil }
        return text
    }

    var summary: String? {
        guard case .string(let text)? = attributes?["summary"] else { return nil }
        return text
    }
}

struct AddCosmeticCard: View {
    let category: CosmeticCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image("CabinetAddArtwork")
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)
                .overlay {
                    addImage
                }

            Text("添加产品")
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(.black)

            if category == .eyeshadow {
                tagPill("待提取产品色系")
                HStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle()
                            .fill(Color(red: 0.84, green: 0.84, blue: 0.84))
                            .frame(width: 28, height: 28)
                    }
                }
            } else {
                tagPill(category == .eyeliner ? "待识别产品材质" : "待识别刷毛材质")
                Text(category == .eyeliner ? "添加后显示眼线产品略述" : "添加后显示毛刷产品略述")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(8)
        .frame(width: 156)
        .background(Color(red: 0.98, green: 0.98, blue: 0.98))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private var addImage: some View {
        ZStack {
            Color.clear
        }
    }

    private func tagPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .light))
            .foregroundStyle(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 2)
            .background(Color.white)
            .clipShape(Capsule())
    }
}
