import SwiftUI

@ViewBuilder
func appRouteDestination(
    _ route: AppRoute,
    session: AppSession,
    path: Binding<NavigationPath>
) -> some View {
    switch route {
    case .aiChat:
        AIChatRouteView(session: session, path: path)
    case .firstTimeUse:
        FirstTimeUseView(session: session, path: path)
    case .makeupPreview:
        MakeupPreviewView(session: session, path: path)
    case .makeupSteps:
        MakeupStepsView(session: session, path: path)
    case .makeupComplete:
        MakeupCompleteView(session: session, path: path)
    case .userProfile:
        UserProfileDetailView()
    }
}
