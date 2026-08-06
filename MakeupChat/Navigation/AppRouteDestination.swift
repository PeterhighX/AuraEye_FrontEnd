import SwiftUI

@ViewBuilder
func appRouteDestination(
    _ route: AppRoute,
    session: AppSession,
    path: Binding<NavigationPath>,
    selectedTab: Binding<Int>
) -> some View {
    switch route {
    case .aiChat:
        AIChatRouteView(session: session, path: path)
    case .firstTimeUse:
        FirstTimeUseView(session: session, path: path)
    case .onboardingCabinet:
        DisplayCabinetView(
            session: session,
            presentationMode: .onboarding,
            onBack: {
                guard !path.wrappedValue.isEmpty else { return }
                path.wrappedValue.removeLast()
            }
        )
    case .makeupPreview:
        MakeupPreviewView(session: session, path: path)
    case .makeupSteps:
        MakeupStepsView(session: session, path: path)
    case .makeupComplete:
        MakeupCompleteView(session: session, path: path, selectedTab: selectedTab)
    case .userProfile:
        UserProfileDetailView(session: session, path: path)
    }
}
