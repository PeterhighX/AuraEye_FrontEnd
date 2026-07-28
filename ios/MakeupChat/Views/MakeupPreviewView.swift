import SwiftUI

struct MakeupPreviewView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            GradientBackgroundView()

            ScrollView {
                VStack(spacing: 24) {
                    MakeupFlowHeaderView(title: "妆容预览") {
                        dismiss()
                    }

                    WeatherSummaryCard(
                        aiMessage: "今日天气多云，气温26℃，紫外线指数偏弱，可以放心大胆的出门哦！"
                    )

                    TipBarView(tipText: "眼神记得微微向下看着镜子来画哦，这样眼皮完全舒展开会让铺色更均匀。")

                    recommendedLookCard

                    VStack(spacing: -64) {
                        stepCard(index: 1, title: "打底铺色", color: Color(red: 0.99, green: 0.92, blue: 0.92))
                        stepCard(index: 2, title: "修容&阴影", color: Color(red: 1.0, green: 0.88, blue: 0.85))
                        stepCard(index: 3, title: "眼睑下至", color: Color(red: 1.0, green: 0.76, blue: 0.68))
                        stepCard(index: 4, title: "卧蚕", color: Color(red: 1.0, green: 0.60, blue: 0.49))
                        stepCard(index: 5, title: "卧蚕", color: Color(red: 0.91, green: 0.42, blue: 0.27), isLast: true)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .navigationBarHidden(true)
    }

    private var recommendedLookCard: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.95, green: 0.94, blue: 0.94))
                .frame(width: 120, height: 120)
                .overlay {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color(red: 0.77, green: 0.65, blue: 0.52).opacity(0.6))
                }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("清透甜美")
                            .font(.system(size: 16, weight: .light))
                        Text("少女感")
                            .font(.system(size: 11, weight: .light))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 2)
                            .background(Color(red: 1.0, green: 0.93, blue: 0.91))
                            .clipShape(Capsule())
                    }
                    Spacer()
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(Color(red: 0.15, green: 0.15, blue: 0.15))
                }

                Text("适合日常出行，妆容简单，5分钟画完")
                    .font(.system(size: 12, weight: .light))
                    .lineSpacing(4)

                HStack {
                    HStack(spacing: 6) {
                        Circle().fill(Color(red: 0.85, green: 0.72, blue: 0.65)).frame(width: 20, height: 20)
                        Circle().fill(Color(red: 0.77, green: 0.65, blue: 0.52)).frame(width: 20, height: 20)
                        Circle().fill(Color(red: 0.55, green: 0.45, blue: 0.38)).frame(width: 20, height: 20)
                    }
                    Spacer()
                    Button {} label: {
                        Text("开始上妆")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .tracking(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(red: 0.15, green: 0.15, blue: 0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.09), radius: 2, y: 2)
        .padding(.horizontal, 16)
    }

    private func stepCard(index: Int, title: String, color: Color, isLast: Bool = false) -> some View {
        HStack {
            HStack(spacing: 17) {
                Text("step \(index)")
                    .font(.system(size: 20, weight: .semibold))
                Text(title)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
            }
            .foregroundStyle(index >= 4 ? .white : Color(red: 0.15, green: 0.15, blue: 0.15).opacity(0.75))

            Spacer()

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(index >= 4 ? Color.white : Color(red: 0.15, green: 0.15, blue: 0.15).opacity(0.3))
                        .frame(width: 4, height: 4)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(height: isLast ? 87 : 120, alignment: .top)
        .background(color.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.09), radius: 2, y: 2)
    }
}

#Preview {
    NavigationStack {
        MakeupPreviewView()
    }
}
