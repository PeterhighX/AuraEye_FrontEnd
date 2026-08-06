import SwiftUI

struct CosmeticProductCard: View {
    let item: CosmeticItem
    let category: CosmeticCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            productImage

            Text(item.displayName)
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(.black)
                .lineLimit(1)

            if category == .eyeshadow {
                tagPill(item.colorFamilyText)
                CosmeticColorSwatches(hexes: item.colorHexes)
            } else {
                tagPill(item.materialText)
                Text(item.summaryText)
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

    private var productImage: some View {
        Group {
            if item.previewPath != nil {
                LocalImageView(
                    storedPath: item.previewPath,
                    systemImage: category.placeholderSymbol
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                CosmeticImagePlaceholder(category: category)
            }
        }
        .frame(width: 140, height: 140)
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
