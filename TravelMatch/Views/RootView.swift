import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if !appState.isLoggedIn {
                LoginView()
            } else if !appState.profilYuklendi {
                yukleniyor
            } else if !appState.profilTamam {
                // Yeni kullanıcı önce kendini tanıtır; seyahat ekleme ana
                // sayfadan, kendi istediği zaman yapılır.
                ProfileEditView(user: appState.currentUser, ilkKurulum: true)
            } else {
                MainTabView()
            }
        }
        .animation(.default, value: appState.isLoggedIn)
        .animation(.default, value: appState.profilYuklendi)
        .preferredColorScheme(.dark)
        .tint(Theme.magenta)
    }

    private var yukleniyor: some View {
        ZStack {
            NightclubBackground()
            ProgressView().tint(Theme.magenta).controlSize(.large)
        }
    }
}

#Preview {
    RootView().environmentObject(AppState())
}
