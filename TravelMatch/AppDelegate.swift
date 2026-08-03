import UIKit
import FirebaseCore
import FirebaseMessaging

/// SwiftUI App lifecycle push bildirimleri için APNs delegate metodlarını
/// doğrudan sunmadığından, bunun için ince bir AppDelegate köprüsü gerekiyor.
final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        NotificationService.shared.configure()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("APNs kaydı başarısız: \(error.localizedDescription)")
    }
}
