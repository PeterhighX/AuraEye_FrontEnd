import SwiftUI

struct CabinetSectionHeader: View {
    let category: CosmeticCategory
w#ww#Rww
    var body: some View {
        HStack {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(category.accentColor)
                    .frame(width: 6, height: 22)

                Text(category.rawValue)
                    .font(.system(size: 20, weight: .regular, design: .rounded))
                    .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.2))
            }

            Spacer()

            Image(systemName: "chevron.right.2")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.2))
        }
        .padding(.horizontal, 16)
    }
}
