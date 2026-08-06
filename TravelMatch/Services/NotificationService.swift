import Foundation
import UIKit
import UserNotifications
import FirebaseMessaging
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class NotificationService: NSObject, ObservableObject {

    static let shared = NotificationService()
    private override init() { super.init() }

    enum PermissionStatus: Equatable {
        case notDetermined, authorized, denied
    }

    @Published var permissionStatus: PermissionStatus = .notDetermined

    func configure() {
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        refreshPermissionStatus()
    }

    func refreshPermissionStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral: self.permissionStatus = .authorized
                case .denied: self.permissionStatus = .denied
                default: self.permissionStatus = .notDetermined
                }
            }
        }
    }

    /// Kullanıcıya sistem izin diyaloğunu gösterir. Reddedilirse bir daha
    /// otomatik gösterilemez — kullanıcıyı Ayarlar'a yönlendirmek gerekir
    /// (bkz. `openSystemSettings`).
    func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        if granted {
            await UIApplication.shared.registerForRemoteNotifications()
        }
        refreshPermissionStatus()
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    /// APNs token Firebase'e ulaştığında (AppDelegate üzerinden) çağrılır.
    /// Token `userSecrets` içinde tutulur — `users` dokümanı herkese açık
    /// okunduğu için push token'ı orada duramaz.
    func saveTokenIfNeeded(_ token: String?) {
        guard let token, let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore().collection("userSecrets").document(uid)
            .setData(["fcmToken": token], merge: true)
    }
}

extension NotificationService: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        Task { @MainActor in
            self.saveTokenIfNeeded(fcmToken)
        }
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    // Uygulama ön plandayken de bildirim göster.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .badge, .sound]
    }
}
