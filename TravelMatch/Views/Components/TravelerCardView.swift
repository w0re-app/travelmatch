import SwiftUI

struct TravelerCardView: View {
    let traveler: TripFellowTraveler
    var matchPercentage: Int? = nil
    let onSendRequest: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.accentGradient)
                        .frame(width: 56, height: 56)
                    Image(systemName: "person.fill")
                        .foregroundStyle(.white)
                        .font(.system(size: 22))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(traveler.user.fullName)
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        if traveler.user.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(Theme.mint)
                                .font(.caption)
                        }
                        Text("· \(traveler.user.age)")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Text(traveler.user.bio)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                if let percentage = matchPercentage, percentage >= MatchScoring.strongMatchThreshold {
                    StrongMatchBadge(percentage: percentage)
                }
            }

            if let percentage = matchPercentage {
                RouteMatchBar(percentage: percentage)
            }

            if !traveler.user.intentTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(traveler.user.intentTags) { tag in
                            Label(tag.rawValue, systemImage: tag.systemImage)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Theme.glassFill)
                                .overlay(Capsule().strokeBorder(Theme.glassStroke, lineWidth: 1))
                                .foregroundStyle(Theme.textPrimary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            actionButton
        }
        .padding(16)
        .glassCard()
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    (matchPercentage ?? 0) >= MatchScoring.strongMatchThreshold ? Theme.magenta.opacity(0.5) : .clear,
                    lineWidth: 1.5
                )
        )
    }

    @ViewBuilder
    private var actionButton: some View {
        switch traveler.matchStatus {
        case .none:
            Button(action: onSendRequest) {
                Label("Eşleşme İsteği Gönder", systemImage: "hand.wave.fill")
            }
            .buttonStyle(.neon)

        case .pendingSentByMe:
            statusPill(text: "İstek Gönderildi", icon: "clock.fill", color: Theme.textSecondary)

        case .pendingReceivedByMe:
            statusPill(text: "Sana İstek Gönderdi", icon: "bell.fill", color: Theme.amber)

        case .accepted:
            statusPill(text: "Eşleştiniz 🎉", icon: "checkmark.circle.fill", color: Theme.mint)

        case .rejected:
            EmptyView()

        case .blocked:
            EmptyView()
        }
    }

    private func statusPill(text: String, icon: String, color: Color) -> some View {
        Label(text, systemImage: icon)
            .frame(maxWidth: .infinity)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(color)
            .padding(.vertical, 12)
            .background(Theme.glassFill)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
