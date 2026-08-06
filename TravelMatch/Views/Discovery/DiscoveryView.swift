import SwiftUI

struct DiscoveryView: View {
    @EnvironmentObject var appState: AppState
    var onSeyahatEkle: () -> Void = {}
    @State private var selectedIntent: IntentTag? = nil
    @State private var showRouteEditor = false

    private var myWaypoints: [RouteWaypoint] { appState.currentTrip?.plannedWaypoints ?? [] }

    /// Her yolcu için güzergah eşleşme yüzdesini hesaplayıp, filtre uygulanmış
    /// listeyi yüzdeye göre azalan sırada döner — bu, "otomatik öneri" sıralamasının kendisi.
    private var scoredTravelers: [(traveler: TripFellowTraveler, percentage: Int?)] {
        let base = selectedIntent == nil
            ? appState.fellowTravelers
            : appState.fellowTravelers.filter { $0.user.intentTags.contains(selectedIntent!) }

        return base
            .map { traveler in
                (traveler, MatchScoring.routeMatchPercentage(mine: myWaypoints, theirs: traveler.sharedTrip.plannedWaypoints))
            }
            .sorted { ($0.percentage ?? -1) > ($1.percentage ?? -1) }
    }

    private var recommended: [(traveler: TripFellowTraveler, percentage: Int?)] {
        scoredTravelers.filter { ($0.percentage ?? 0) >= MatchScoring.strongMatchThreshold }
    }

    private var others: [(traveler: TripFellowTraveler, percentage: Int?)] {
        scoredTravelers.filter { ($0.percentage ?? 0) < MatchScoring.strongMatchThreshold }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NightclubBackground()

                VStack(spacing: 0) {
                    if appState.currentTrip == nil {
                        seyahatYokDurumu
                    } else {
                    if let trip = appState.currentTrip {
                        tripHeader(trip)
                    }

                    NotificationPermissionBanner()

                    filterBar

                    if scoredTravelers.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 12) {
                                if !recommended.isEmpty {
                                    sectionHeader("🔥 Senin İçin Önerilenler", subtitle: "Güzergahın en çok bunlarla örtüşüyor")
                                    ForEach(recommended, id: \.traveler.id) { item in
                                        TravelerCardView(traveler: item.traveler, matchPercentage: item.percentage) {
                                            appState.sendMatchRequest(to: item.traveler)
                                        }
                                    }
                                    sectionHeader("Diğerleri", subtitle: nil)
                                }
                                ForEach(others, id: \.traveler.id) { item in
                                    TravelerCardView(traveler: item.traveler, matchPercentage: item.percentage) {
                                        appState.sendMatchRequest(to: item.traveler)
                                    }
                                }
                            }
                            .padding(16)
                            .padding(.bottom, 90) // yüzen tab bar payı
                        }
                    }
                    }
                }
            }
            .navigationTitle("Bu Seyahatte")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showRouteEditor = true
                    } label: {
                        Image(systemName: "map.fill")
                            .foregroundStyle(Theme.textPrimary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        appState.toggleIncognito()
                    } label: {
                        Image(systemName: appState.currentUser.isIncognito ? "eye.slash.fill" : "eye.fill")
                            .foregroundStyle(Theme.textPrimary)
                    }
                }
            }
            .sheet(isPresented: $showRouteEditor) {
                RouteBuilderView(onFinished: { showRouteEditor = false }, showsSkip: false)
            }
            // Eşleşme hataları eskiden sessizce yutuluyordu; artık görünür.
            .alert("Eşleşme Hatası", isPresented: Binding(
                get: { appState.matchErrorMessage != nil },
                set: { if !$0 { appState.matchErrorMessage = nil } }
            )) {
                Button("Tamam", role: .cancel) { appState.matchErrorMessage = nil }
            } message: {
                Text(appState.matchErrorMessage ?? "")
            }
        }
    }

    private func sectionHeader(_ title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func tripHeader(_ trip: Trip) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Theme.primaryGradient).frame(width: 34, height: 34)
                Image(systemName: trip.type.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(trip.locationIdentifier).font(.subheadline.bold()).foregroundStyle(Theme.textPrimary)
                Text(trip.type == .flight ? "Uçuş moduyla eşleşiliyor" : "Otel moduyla eşleşiliyor")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            if appState.currentUser.isIncognito {
                Label("Gizli Mod", systemImage: "eye.slash.fill")
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.glassFill)
                    .foregroundStyle(Theme.textSecondary)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)

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
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: "Tümü", isSelected: selectedIntent == nil) {
                    selectedIntent = nil
                }
                ForEach(IntentTag.allCases) { tag in
                    filterChip(title: tag.rawValue, isSelected: selectedIntent == tag) {
                        selectedIntent = (selectedIntent == tag) ? nil : tag
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? AnyShapeStyle(Theme.primaryGradient) : AnyShapeStyle(Theme.glassFill))
                .foregroundStyle(.white)
                .overlay(Capsule().strokeBorder(isSelected ? Color.clear : Theme.glassStroke, lineWidth: 1))
                .clipShape(Capsule())
        }
    }

    private var seyahatYokDurumu: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "airplane.circle")
                .font(.system(size: 44))
                .foregroundStyle(Theme.textTertiary)
            Text("Önce bir seyahat ekle")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Text("Uçuşunu ya da otelini ekledikten sonra aynı yolda olan kişiler burada listelenir.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Ana Sayfaya Dön") { onSeyahatEkle() }
                .buttonStyle(.ghost)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "person.2.slash")
                .font(.system(size: 40))
                .foregroundStyle(Theme.textTertiary)
            Text("Şu an bu filtreyle kimse bulunamadı")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    let state = AppState()
    state.currentTrip = MockData.sampleFlightTrip
    state.fellowTravelers = MockData.fellowTravelers(for: MockData.sampleFlightTrip)
    return DiscoveryView().environmentObject(state).preferredColorScheme(.dark)
}
