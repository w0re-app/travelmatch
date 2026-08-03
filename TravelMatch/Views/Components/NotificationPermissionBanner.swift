import SwiftUI

struct NotificationPermissionBanner: View {
    @ObservedObject var notificationService = NotificationService.shared

    var body: some View {
        switch notificationService.permissionStatus {
        case .authorized:
            EmptyView()

        case .notDetermined:
            banner(
                title: "Bildirimleri Aç",
                subtitle: "Eşleşme isteklerini ve mesajları kaçırma.",
                actionTitle: "Aç",
                accent: Theme.violet
            ) {
                Task { await notificationService.requestAuthorization() }
            }

        case .denied:
            banner(
                title: "Bildirimler Kapalı",
                subtitle: "Eşleşme ve mesaj bildirimleri için Ayarlar'dan izin ver.",
                actionTitle: "Ayarlar",
                accent: Theme.amber
            ) {
                notificationService.openSystemSettings()
            }
        }
    }

    private func banner(title: String, subtitle: String, actionTitle: String, accent: Color, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.badge.fill")
                .foregroundStyle(accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold()).foregroundStyle(Theme.textPrimary)
                Text(subtitle).font(.caption).foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            Button(actionTitle, action: action)
                .buttonStyle(.ghost)
        }
        .padding(12)
        .glassCard(cornerRadius: 14)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .task {
            notificationService.refreshPermissionStatus()
        }
    }
}
