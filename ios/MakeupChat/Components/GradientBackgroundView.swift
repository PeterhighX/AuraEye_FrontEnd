import SwiftUI

struct GradientBackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.60, blue: 0.42),
                    Color(red: 0.96, green: 0.66, blue: 0.85),
                    Color(red: 0.72, green: 0.74, blue: 1.0),
                    Color(red: 0.83, green: 0.85, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            DotGridPattern()
                .opacity(0.35)
        }
        .ignoresSafeArea()
    }
}

private struct DotGridPattern: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 20
            let dotSize: CGFloat = 2
            let cols = Int(size.width / spacing) + 1
            let rows = Int(size.height / spacing) + 1

            for row in 0..<rows {
                for col in 0..<cols {
                    let rect = CGRect(
                        x: CGFloat(col) * spacing,
                        y: CGFloat(row) * spacing,
                        width: dotSize,
                        height: dotSize
                    )
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.5)))
                }
            }
        }
    }
}
