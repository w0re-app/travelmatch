import SwiftUI
import FirebaseCore

@main
struct TravelMatchApp: App {
    // FirebaseApp.configure() ve push bildirim kurulumu artık AppDelegate'te yapılıyor.
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}
