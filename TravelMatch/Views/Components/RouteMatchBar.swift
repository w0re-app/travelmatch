import SwiftUI

/// Güzergah örtüşme yüzdesini gösteren gradyanlı ilerleme çubuğu.
struct RouteMatchBar: View {
    let percentage: Int

    private var isStrong: Bool { percentage >= MatchScoring.strongMatchThreshold }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "map.fill")
                    .font(.caption2)
                    .foregroundStyle(isStrong ? Theme.coral : Theme.textSecondary)
                Text("Güzergah Eşleşmesi")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("%\(percentage)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isStrong ? Theme.textPrimary : Theme.textSecondary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.glassFill)
                    Capsule()
                        .fill(Theme.primaryGradient)
                        .frame(width: proxy.size.width * CGFloat(percentage) / 100)
                        .neonGlow(isStrong ? Theme.magenta.opacity(0.5) : .clear, radius: 6)
                }
            }
            .frame(height: 6)
        }
    }
}

/// Kart köşesinde beliren küçük "güçlü eşleşme" rozeti.
struct StrongMatchBadge: View {
    let percentage: Int

    var body: some View {
        Label("%\(percentage) Güçlü Eşleşme", systemImage: "flame.fill")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Theme.primaryGradient)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .neonGlow(Theme.coral.opacity(0.6), radius: 8)
    }
}
