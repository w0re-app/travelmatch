import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.isLoggedIn {
                // Girişten sonra doğrudan ana sayfa açılır. Seyahat ekleme artık
                // zorunlu bir ilk adım değil, ana sayfadan başlatılan bir akış.
                MainTabView()
            } else {
                LoginView()
            }
        }
        .animation(.default, value: appState.isLoggedIn)
        .preferredColorScheme(.dark)
        .tint(Theme.magenta)
    }
}

#Preview {
    RootView().environmentObject(AppState())
}
