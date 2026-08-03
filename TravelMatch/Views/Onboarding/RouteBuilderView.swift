import SwiftUI

struct RouteBuilderView: View {
    @EnvironmentObject var appState: AppState
    var onFinished: () -> Void = {}
    var showsSkip: Bool = true

    @State private var query: String = ""
    @State private var selected: [RouteWaypoint] = []
    @FocusState private var searchFocused: Bool

    private var suggestions: [RouteWaypoint] {
        WaypointCatalog.search(query).filter { candidate in
            !selected.contains(where: { $0.id == candidate.id })
        }
    }

    var body: some View {
        ZStack {
            NightclubBackground()

            VStack(spacing: 0) {
                header
                searchField

                if !selected.isEmpty {
                    selectedChips
                }

                suggestionList
                Spacer(minLength: 0)
                saveButton
            }
        }
        .onAppear {
            selected = appState.currentTrip?.plannedWaypoints ?? []
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Güzergahını Ekle")
                .font(.title2.bold())
                .foregroundStyle(Theme.textPrimary)
            Text("Bu tatilde uğramayı düşündüğün plaj, köy, kasaba ya da noktaları seç. Aynı yere gidenleri profilinde göreceksin.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.textTertiary)
            TextField("", text: $query, prompt: Text("Örn: Akyaka, Kaş, Alaçatı…").foregroundStyle(Theme.textTertiary))
                .foregroundStyle(Theme.textPrimary)
                .focused($searchFocused)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.glassFill)
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.glassStroke, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 20)
    }

    private var selectedChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(selected) { waypoint in
                    HStack(spacing: 6) {
                        Image(systemName: waypoint.category.systemImage)
                        Text(waypoint.name)
                        Button {
                            withAnimation { selected.removeAll { $0.id == waypoint.id } }
                        } label: {
                            Image(systemName: "xmark")
                        }
                    }
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.primaryGradient)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
    }

    private var suggestionList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(suggestions) { waypoint in
                    Button {
                        withAnimation {
                            selected.append(waypoint)
                            query = ""
                        }
                    } label: {
                        suggestionRow(waypoint)
                    }
                    .buttonStyle(.plain)
                }

                if suggestions.isEmpty && !query.isEmpty {
                    Text("\"\(query)\" ile eşleşen bir yer bulunamadı.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.top, 24)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
    }

    private func suggestionRow(_ waypoint: RouteWaypoint) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Theme.accentGradient).frame(width: 36, height: 36)
                Image(systemName: waypoint.category.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(waypoint.name).font(.subheadline.bold()).foregroundStyle(Theme.textPrimary)
                Text("\(waypoint.district), \(waypoint.province) · \(waypoint.category.rawValue)")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(Theme.violet)
        }
        .padding(12)
        .glassCard(cornerRadius: 14)
    }

    private var saveButton: some View {
        VStack(spacing: 8) {
            Button {
                appState.updateTripRoute(selected)
                onFinished()
            } label: {
                Text(selected.isEmpty ? "Şimdilik Atla" : "Güzergahı Kaydet (\(selected.count))")
            }
            .buttonStyle(.neon)

            if showsSkip && !selected.isEmpty {
                Button("Atla") {
                    onFinished()
                }
                .buttonStyle(.ghost)
            }
        }
        .padding(16)
        .background(Theme.midnight.opacity(0.4))
    }
}

#Preview {
    RouteBuilderView().environmentObject(AppState()).preferredColorScheme(.dark)
}
