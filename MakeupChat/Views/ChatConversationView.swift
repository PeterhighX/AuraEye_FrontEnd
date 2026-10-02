import SwiftUI

struct ChatConversationView: View {
    enum LayoutMode { case full, keyboard }

    @Bindable var viewModel: ChatViewModel
    let layoutMode: LayoutMode
    var onBack: () -> Void = {}
    @State private var draftText = ""

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 24) {
                if let user = viewModel.user {
                    ProfileHeaderView(user: user, onBack: onBack)
                }
                KnowledgeTipBar(surface: "chat")
            }
            .padding(.top, 8)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                            if startsNewDay(at: index) {
                                Text(dayLabel(for: message.createdAt))
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .padding(.top, index == 0 ? 20 : 28)
                                    .padding(.bottom, 8)
                            }

                            ChatBubbleView(message: message) {
                                viewModel.retry(message: message)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .id(message.id)
                        }
                    }
                }
                .defaultScrollAnchor(.top)
                .onChange(of: viewModel.messages.map(\.id)) { oldIDs, newIDs in
                    guard oldIDs != newIDs, let newestID = newIDs.last else { return }
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(newestID, anchor: .bottom)
                    }
                }

                MakeupInputBar(
                    text: $draftText,
                    onSend: sendDraft,
                    isSending: viewModel.isSending,
                    initialFocus: layoutMode == .keyboard
                )
                .background(.ultraThinMaterial)
            }
        }
        .onAppear(perform: viewModel.reload)
    }

    private func sendDraft() {
        guard viewModel.send(text: draftText) else { return }
        draftText = ""
    }

    private func startsNewDay(at index: Int) -> Bool {
        guard index > 0 else { return true }
        return !Calendar.current.isDate(
            viewModel.messages[index].createdAt,
            inSameDayAs: viewModel.messages[index - 1].createdAt
        )
    }

    private func dayLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "今天" }
        if calendar.isDateInYesterday(date) { return "昨天" }
        return date.formatted(.dateTime.year().month().day())
    }
}

#Preview {
    Text("ChatConversationView requires an authenticated chat session")
}
