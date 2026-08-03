import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if !appState.isLoggedIn {
                LoginView()
            } else if appState.verificationState == .verified {
                if appState.routeStepCompleted {
                    MainTabView()
                } else {
                    RouteBuilderView {
                        appState.routeStepCompleted = true
                    }
                }
            } else if appState.verificationState == .verifying || isFailedState {
                VerificationView()
            } else {
                TripEntryView()
            }
        }
        .animation(.default, value: appState.isLoggedIn)
        .animation(.default, value: appState.verificationState)
        .animation(.default, value: appState.routeStepCompleted)
        .preferredColorScheme(.dark)
        .tint(Theme.magenta)
    }

    private var isFailedState: Bool {
        if case .failed = appState.verificationState { return true }
        return false
    }
}

#Preview {
    RootView().environmentObject(AppState())
}
