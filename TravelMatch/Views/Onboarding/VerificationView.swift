import SwiftUI

struct VerificationView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            NightclubBackground()

            VStack(spacing: 20) {
                switch appState.verificationState {
                case .idle:
                    EmptyView()

                case .verifying:
                    ProgressView()
                        .controlSize(.large)
                        .tint(Theme.magenta)
                    Text("Rezervasyonun doğrulanıyor…")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text("PNR / rezervasyon kodun sağlayıcı ile kontrol ediliyor.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)

                case .verified:
                    ZStack {
                        Circle().fill(Theme.mint.opacity(0.25)).frame(width: 96, height: 96).blur(radius: 16)
                        Image(systemName: "checkmark.seal.fill")
                            .resizable()
                            .frame(width: 64, height: 64)
                            .foregroundStyle(Theme.mint)
                    }
                    Text("Doğrulandı!")
                        .font(.title2.bold())
                        .foregroundStyle(Theme.textPrimary)
                    if let trip = appState.currentTrip {
                        Text(trip.locationIdentifier)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                        if trip.verificationMethod == .document {
                            Label("Biniş kartı/belge ile doğrulandı", systemImage: "doc.text.viewfinder")
                                .font(.caption)
                                .foregroundStyle(Theme.violet)
                        }
                    }
                    Text("Artık bu seyahati paylaşan kişileri görebilirsin.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textTertiary)
                        .multilineTextAlignment(.center)

                case .failed(let reason):
                    Image(systemName: "xmark.octagon.fill")
                        .resizable()
                        .frame(width: 64, height: 64)
                        .foregroundStyle(Theme.rose)
                    Text("Doğrulama başarısız")
                        .font(.title2.bold())
                        .foregroundStyle(Theme.textPrimary)
                    Text(reason)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("Tekrar Dene") {
                        appState.resetTrip()
                    }
                    .buttonStyle(.ghost)
                }
            }
            .padding(32)
        }
    }
}

#Preview {
    VerificationView().environmentObject(AppState()).preferredColorScheme(.dark)
}
