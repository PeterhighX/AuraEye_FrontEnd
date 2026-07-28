import SwiftUI

struct WeatherSummaryCard: View {
    var aiMessage: String
    var showFirstTimeHint: Bool = false

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(red: 1.0, green: 0.93, blue: 0.91).opacity(0.4))
                .shadow(color: Color.black.opacity(0.09), radius: 2, y: 2)
                .frame(height: showFirstTimeHint ? 205 : 161)

            VStack(spacing: 0) {
                HStack(alignment: .bottom) {
                    Image(systemName: "cloud.sun.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.white)
                        .frame(width: 124, height: 81, alignment: .leading)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(alignment: .top, spacing: 2) {
                            Text("26")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(Color(red: 0.33, green: 0.33, blue: 0.33))
                            VStack(alignment: .leading, spacing: 0) {
                                Text("℃")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color(red: 0.62, green: 0.62, blue: 0.62))
                                Text("多云")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color(red: 0.62, green: 0.62, blue: 0.62))
                            }
                        }

                        Text("福田区")
                            .font(.system(size: 12, weight: .light))
                            .foregroundStyle(Color(red: 0.4, green: 0.4, blue: 0.4))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.45))
                            .clipShape(Capsule())

                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.45))
                                .frame(height: 9)
                            Capsule()
                                .fill(Color(red: 1.0, green: 0.55, blue: 0.41))
                                .frame(width: 60, height: 9)
                        }
                        .frame(width: 183)

                        HStack {
                            HStack(spacing: 3) {
                                Image(systemName: "sun.max")
                                    .font(.system(size: 12))
                                Text("紫外线指数")
                                    .font(.system(size: 12))
                            }
                            Text("19")
                                .font(.system(size: 12))
                            Spacer()
                            Text("弱")
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(Color(red: 0.4, green: 0.4, blue: 0.4))
                        .frame(width: 183)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)

                Spacer(minLength: showFirstTimeHint ? 24 : 16)

                HStack(alignment: .top, spacing: 12) {
                    Image("AvatarAI")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())

                    Text(aiMessage)
                        .font(.system(size: 14, weight: .thin))
                        .foregroundStyle(Color(red: 0.2, green: 0.2, blue: 0.2))
                        .lineSpacing(4)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.75))
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 0,
                                bottomLeadingRadius: 13,
                                bottomTrailingRadius: 13,
                                topTrailingRadius: 13
                            )
                        )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .padding(.horizontal, 16)
    }
}
