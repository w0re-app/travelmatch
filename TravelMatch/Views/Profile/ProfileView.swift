import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var notificationService = NotificationService.shared
    @State private var showingEdit = false

    var body: some View {
        NavigationStack {
            ZStack {
                NightclubBackground()

                Form {
                    Section {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle().fill(Theme.primaryGradient).frame(width: 64, height: 64)
                                Image(systemName: "person.fill").foregroundStyle(.white).font(.system(size: 26))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(appState.currentUser.fullName).font(.title3.bold()).foregroundStyle(Theme.textPrimary)
                                Text("\(appState.currentUser.age) yaşında").foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            Button("Düzenle") { showingEdit = true }
                                .buttonStyle(.ghost)
                        }
                        .padding(.vertical, 6)
                        .listRowBackground(Color.clear)

                        if !appState.currentUser.bio.isEmpty {
                            Text(appState.currentUser.bio)
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                                .listRowBackground(Color.clear)
                        }
                    }

                    Section {
                        if appState.currentUser.intentTags.isEmpty {
                            Text("Henüz seçilmedi — düzenle'ye dokunarak ekleyebilirsin.")
                                .font(.caption)
                                .foregroundStyle(Theme.textTertiary)
                                .listRowBackground(Color.clear)
                        } else {
                            ForEach(appState.currentUser.intentTags) { tag in
                                Label(tag.rawValue, systemImage: tag.systemImage)
                                    .foregroundStyle(Theme.textPrimary)
                                    .listRowBackground(Color.clear)
                            }
                        }
                    } header: {
                        Text("İlgi Alanları").foregroundStyle(Theme.textTertiary)
                    }

                    Section {
                        HStack {
                            Label("Bildirim İzni", systemImage: "bell.fill").foregroundStyle(Theme.textPrimary)
                            Spacer()
                            statusLabel
                        }
                        .listRowBackground(Color.clear)

                        if notificationService.permissionStatus != .authorized {
                            Button(notificationService.permissionStatus == .denied ? "Ayarları Aç" : "Bildirimlere İzin Ver") {
                                if notificationService.permissionStatus == .denied {
                                    notificationService.openSystemSettings()
                                } else {
                                    Task { await notificationService.requestAuthorization() }
                                }
                            }
                            .foregroundStyle(Theme.violet)
                            .listRowBackground(Color.clear)
                        }
                    } header: {
                        Text("Bildirimler").foregroundStyle(Theme.textTertiary)
                    }

                    Section {
                        Toggle(isOn: Binding(
                            get: { appState.currentUser.isIncognito },
                            set: { _ in appState.toggleIncognito() }
                        )) {
                            Label("Gizli Mod", systemImage: "eye.slash.fill").foregroundStyle(Theme.textPrimary)
                        }
                        .tint(Theme.magenta)
                        .listRowBackground(Color.clear)

                        Text("Gizli mod açıkken, aynı seyahati paylaştığın kişilerin listesinde görünmezsin.")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                            .listRowBackground(Color.clear)
                    } header: {
                        Text("Gizlilik").foregroundStyle(Theme.textTertiary)
                    }

                    if let trip = appState.currentTrip {
                        Section {
                            Label(trip.locationIdentifier, systemImage: trip.type.systemImage)
                                .foregroundStyle(Theme.textPrimary)
                                .listRowBackground(Color.clear)
                            Button(role: .destructive) {
                                appState.resetTrip()
                            } label: {
                                Text("Seyahati Sonlandır")
                            }
                            .foregroundStyle(Theme.rose)
                            .listRowBackground(Color.clear)
                        } header: {
                            Text("Aktif Seyahat").foregroundStyle(Theme.textTertiary)
                        }
                    }

                    Section {
                        Button(role: .destructive) {
                            appState.signOut()
                        } label: {
                            Text("Çıkış Yap")
                        }
                        .foregroundStyle(Theme.rose)
                        .listRowBackground(Color.clear)
                    }
                }
                .scrollContentBackground(.hidden)
                .safeAreaPadding(.bottom, 80)
            }
            .navigationTitle("Profilim")
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingEdit) {
                ProfileEditView(user: appState.currentUser)
            }
            .task {
                notificationService.refreshPermissionStatus()
            }
        }
    }

    private var statusLabel: some View {
        Group {
            switch notificationService.permissionStatus {
            case .authorized: Text("Açık").foregroundStyle(Theme.mint)
            case .denied: Text("Kapalı").foregroundStyle(Theme.rose)
            case .notDetermined: Text("Belirlenmedi").foregroundStyle(Theme.textSecondary)
            }
        }
        .font(.subheadline)
    }
}

#Preview {
    ProfileView().environmentObject(AppState()).preferredColorScheme(.dark)
}
