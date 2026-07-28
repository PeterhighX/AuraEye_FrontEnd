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
                if let firstTag = item.tags.first {
                    tagPill(firstTag)
                }
                CosmeticColorSwatches(hexes: item.colorHexes)
            } else {
                ForEach(item.tags, id: \.self) { tag in
                    tagPill(tag)
                }
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
        .aspectRatio(1, contentMode: .fit)
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
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(red: 0.89, green: 0.89, blue: 0.88))
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(Color(red: 0.55, green: 0.55, blue: 0.55))
                }

            Text("添加产品")
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(.black)

            Text("SKU")
                .font(.system(size: 11, weight: .light))
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 2)
                .background(Color.white)
                .clipShape(Capsule())
        }
        .padding(8)
        .frame(width: 156)
        .background(Color(red: 0.98, green: 0.98, blue: 0.98))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
