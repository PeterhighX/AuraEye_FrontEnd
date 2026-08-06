import SwiftUI

struct PlaceholderTabView: View {
    let title: String
    let systemImage: String

    var body: some View {
        ContentUnavailableView(title, systemImage: systemImage, description: Text("即将上线"))
    }
}
