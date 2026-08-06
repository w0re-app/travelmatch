import SwiftUI

/// Girişten sonra açılan ana sayfa. Aktif seyahati, yeni seyahat ekleme
/// butonunu ve geçmiş seyahatleri gösterir.
struct HomeView: View {
    @EnvironmentObject var appState: AppState
    var onSeyahateGit: () -> Void = {}

    @State private var showTripEntry = false
    @State private var showRouteEditor = false
    @State private var silinecek: (docId: String, trip: Trip)?

    var body: some View {
        NavigationStack {
            ZStack {
                NightclubBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        selamlama

                        if let trip = appState.currentTrip {
                            aktifSeyahatKarti(trip)
                        } else {
                            bosDurum
                        }

                        yeniSeyahatButonu

                        if !appState.gecmisSeyahatler.isEmpty {
                            gecmisBolumu
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 90)
                }
            }
            .navigationTitle("TravelMatch")
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showTripEntry, onDismiss: {
                // Seyahat kaydedildiyse hemen ardından güzergah adımını aç —
                // plaj/tarihi yer seçimi akışın doğal parçası olsun.
                if appState.currentTrip != nil, appState.currentTrip?.plannedWaypoints.isEmpty == true {
                    showRouteEditor = true
                }
            }) {
                TripEntryView(onCompleted: { showTripEntry = false })
            }
            .sheet(isPresented: $showRouteEditor) {
                RouteBuilderView(onFinished: { showRouteEditor = false }, showsSkip: false)
            }
            .confirmationDialog(
                "Bu seyahat ve ona bağlı rezervasyon kodu kalıcı olarak silinecek.",
                isPresented: Binding(get: { silinecek != nil }, set: { if !$0 { silinecek = nil } }),
                titleVisibility: .visible
            ) {
                Button("Sil", role: .destructive) {
                    if let hedef = silinecek { appState.seyahatiSil(docId: hedef.docId) }
                    silinecek = nil
                }
                Button("Vazgeç", role: .cancel) { silinecek = nil }
            }
            .task {
                await appState.seyahatleriYenile()
            }
        }
    }

    // MARK: - Parçalar

    private var selamlama: some View {
        HStack(spacing: 12) {
            AvatarView(uid: appState.currentUser.id, boyut: 48, surum: appState.avatarSurumu)
            VStack(alignment: .leading, spacing: 2) {
                Text("Merhaba")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                Text(appState.currentUser.fullName.isEmpty ? "Yolcu" : appState.currentUser.fullName)
                    .font(.title3.bold())
                    .foregroundStyle(Theme.textPrimary)
            }
            Spacer()
        }
    }

    private func aktifSeyahatKarti(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Theme.primaryGradient).frame(width: 44, height: 44)
                    Image(systemName: trip.type.systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(trip.locationIdentifier)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text(tarihAraligi(trip))
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                if trip.isVerified {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.mint)
                }
            }

            if !trip.plannedWaypoints.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(trip.plannedWaypoints) { waypoint in
                            Label(waypoint.name, systemImage: waypoint.category.systemImage)
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Theme.glassFill)
                                .foregroundStyle(Theme.cyan)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                Button {
                    onSeyahateGit()
                } label: {
                    Label("Yol Arkadaşları", systemImage: "person.2.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.neon)

                Button {
                    showRouteEditor = true
                } label: {
                    Image(systemName: "map.fill")
                }
                .buttonStyle(.ghost)
            }
        }
        .padding(16)
        .glassCard()
    }

    private var bosDurum: some View {
        VStack(spacing: 10) {
            Image(systemName: "airplane.departure")
                .font(.system(size: 36))
                .foregroundStyle(Theme.textTertiary)
            Text("Aktif seyahatin yok")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Text("Uçuşunu ya da otelini ekle, aynı yolda olan kişileri gör.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .glassCard()
    }

    private var yeniSeyahatButonu: some View {
        Button {
            showTripEntry = true
        } label: {
            Label("Yeni Seyahat Ekle", systemImage: "plus.circle.fill")
        }
        .buttonStyle(.neon)
    }

    private var gecmisBolumu: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("GEÇMİŞ SEYAHATLER")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.textTertiary)
                .padding(.top, 6)

            ForEach(appState.gecmisSeyahatler, id: \.docId) { kayit in
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Theme.glassFill).frame(width: 38, height: 38)
                        Image(systemName: kayit.trip.type.systemImage)
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(kayit.trip.locationIdentifier)
                            .font(.subheadline.bold())
                            .foregroundStyle(Theme.textPrimary)
                        Text(tarihAraligi(kayit.trip))
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                    Spacer()
                    Button {
                        silinecek = kayit
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(Theme.rose)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .glassCard(cornerRadius: 16)
            }
        }
    }

    private func tarihAraligi(_ trip: Trip) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "d MMM"
        let bas = f.string(from: trip.startDate)
        let bit = f.string(from: trip.endDate)
        if trip.type == .flight {
            f.dateFormat = "d MMM HH:mm"
            return f.string(from: trip.startDate)
        }
        return bas == bit ? bas : "\(bas) – \(bit)"
    }
}

#Preview {
    HomeView().environmentObject(AppState()).preferredColorScheme(.dark)
}
