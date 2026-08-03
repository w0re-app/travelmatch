import SwiftUI

struct MatchesListView: View {
    @EnvironmentObject var appState: AppState

    private var pendingReceived: [MatchRecord] { appState.matches.filter { $0.status == .pendingReceivedByMe } }
    private var active: [MatchRecord] { appState.matches.filter { $0.status == .accepted } }
    private var sentPending: [MatchRecord] { appState.matches.filter { $0.status == .pendingSentByMe } }

    var body: some View {
        NavigationStack {
            ZStack {
                NightclubBackground()

                if appState.matches.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            if !pendingReceived.isEmpty {
                                sectionHeader("Sana Gelen İstekler")
                                VStack(spacing: 10) {
                                    ForEach(pendingReceived) { match in
                                        PendingMatchRow(match: match)
                                    }
                                }
                            }

                            if !active.isEmpty {
                                sectionHeader("Eşleşmeler")
                                VStack(spacing: 10) {
                                    ForEach(active) { match in
                                        NavigationLink(value: match) {
                                            MatchRowView(match: match)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }

                            if !sentPending.isEmpty {
                                sectionHeader("Gönderdiğin İstekler")
                                VStack(spacing: 10) {
                                    ForEach(sentPending) { match in
                                        MatchRowView(match: match)
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .padding(.bottom, 90)
                    }
                }
            }
            .navigationTitle("Eşleşmeler")
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: MatchRecord.self) { match in
                ChatView(match: match)
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.bold))
            .foregroundStyle(Theme.textTertiary)
            .padding(.top, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(Theme.textTertiary)
            Text("Henüz bir eşleşmen yok")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Text("Keşfet sekmesinden istek göndermeye başla.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
    }
}

private struct PendingMatchRow: View {
    @EnvironmentObject var appState: AppState
    let match: MatchRecord

    var body: some View {
        HStack(spacing: 12) {
            avatar
            VStack(alignment: .leading, spacing: 2) {
                Text(match.otherUser.fullName).font(.subheadline.bold()).foregroundStyle(Theme.textPrimary)
                Text(match.sharedTrip.locationIdentifier)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()

            Button {
                appState.respondToMatch(match, accept: false)
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.rose)
                    .frame(width: 34, height: 34)
                    .background(Theme.glassFill)
                    .clipShape(Circle())
            }

            Button {
                appState.respondToMatch(match, accept: true)
            } label: {
                Image(systemName: "checkmark")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Theme.primaryGradient)
                    .clipShape(Circle())
            }
        }
        .padding(12)
        .glassCard(cornerRadius: 16)
    }

    private var avatar: some View {
        ZStack {
            Circle().fill(Theme.accentGradient).frame(width: 44, height: 44)
            Image(systemName: "person.fill").foregroundStyle(.white)
        }
    }
}

private struct MatchRowView: View {
    let match: MatchRecord

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Theme.accentGradient).frame(width: 44, height: 44)
                Image(systemName: "person.fill").foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(match.otherUser.fullName).font(.subheadline.bold()).foregroundStyle(Theme.textPrimary)
                Text(match.lastMessagePreview ?? match.sharedTrip.locationIdentifier)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            if match.status == .pendingSentByMe {
                Text("Bekliyor")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Theme.textTertiary)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(12)
        .glassCard(cornerRadius: 16)
    }
}

#Preview {
    MatchesListView().environmentObject(AppState()).preferredColorScheme(.dark)
}
