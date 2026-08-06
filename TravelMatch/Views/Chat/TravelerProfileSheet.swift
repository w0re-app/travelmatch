import SwiftUI

struct TravelerProfileSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let match: MatchRecord
    var onBlocked: () -> Void = {}

    @State private var showReportSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                NightclubBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        AvatarView(uid: match.otherUser.id, boyut: 96)
                            .neonGlow(Theme.magenta, radius: 18)
                            .padding(.top, 8)

                        VStack(spacing: 4) {
                            HStack(spacing: 6) {
                                Text(match.otherUser.fullName)
                                    .font(.title2.bold())
                                    .foregroundStyle(Theme.textPrimary)
                                if match.otherUser.isVerified {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundStyle(Theme.mint)
                                }
                            }
                            Text("\(match.otherUser.age) yaşında")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                        }

                        if !match.otherUser.bio.isEmpty {
                            Text(match.otherUser.bio)
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }

                        if !match.otherUser.intentTags.isEmpty {
                            FlowTagsView(tags: match.otherUser.intentTags)
                                .padding(.horizontal, 16)
                        }

                        sharedTripCard

                        if !sharedWaypoints.isEmpty {
                            sharedWaypointsCard
                        }

                        Button(role: .destructive) {
                            showReportSheet = true
                        } label: {
                            Label("Bildir / Engelle", systemImage: "flag.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.ghost)
                        .foregroundStyle(Theme.rose)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                        Spacer(minLength: 24)
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            .sheet(isPresented: $showReportSheet) {
                ReportUserSheet(reportedUser: match.otherUser, matchId: match.id) {
                    onBlocked()
                    dismiss()
                }
                .environmentObject(appState)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    /// Kendi seyahatindeki güzergah ile karşı tarafın güzergahının kesişimi.
    private var sharedWaypoints: [RouteWaypoint] {
        let mine = Set((appState.currentTrip?.plannedWaypoints ?? []).map(\.id))
        return match.sharedTrip.plannedWaypoints.filter { mine.contains($0.id) }
    }

    private var sharedWaypointsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ortak Duraklar 🎉").font(.caption).foregroundStyle(Theme.textTertiary)
            ForEach(sharedWaypoints) { waypoint in
                HStack(spacing: 10) {
                    Image(systemName: waypoint.category.systemImage)
                        .foregroundStyle(Theme.cyan)
                    Text(waypoint.name).foregroundStyle(Theme.textPrimary)
                    Spacer()
                }
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 16)
        .padding(.horizontal, 16)
    }

    private var sharedTripCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Theme.accentGradient).frame(width: 40, height: 40)
                Image(systemName: match.sharedTrip.type.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Ortak Seyahat").font(.caption).foregroundStyle(Theme.textTertiary)
                Text(match.sharedTrip.locationIdentifier)
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.textPrimary)
            }
            Spacer()
        }
        .padding(14)
        .glassCard(cornerRadius: 16)
        .padding(.horizontal, 16)
    }
}

/// İlgi alanı etiketlerini satır satır saran basit bir "flow layout".
struct FlowTagsView: View {
    let tags: [IntentTag]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tags) { tag in
                    Label(tag.rawValue, systemImage: tag.systemImage)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.glassFill)
                        .overlay(Capsule().strokeBorder(Theme.glassStroke, lineWidth: 1))
                        .foregroundStyle(Theme.textPrimary)
                        .clipShape(Capsule())
                }
            }
        }
    }
}

#Preview {
    TravelerProfileSheet(match: MockData.sampleMatches()[0])
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
