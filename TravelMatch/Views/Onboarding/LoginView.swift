import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @State private var pulse = false
    @State private var showSartlar = false
    @State private var showGizlilik = false

    var body: some View {
        ZStack {
            NightclubBackground()

            VStack(spacing: 28) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Theme.primaryGradient)
                        .frame(width: 120, height: 120)
                        .blur(radius: 22)
                        .opacity(pulse ? 0.9 : 0.5)
                        .scaleEffect(pulse ? 1.1 : 0.9)
                        .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: pulse)

                    Image(systemName: "airplane.circle.fill")
                        .resizable()
                        .frame(width: 92, height: 92)
                        .foregroundStyle(Theme.primaryGradient)
                }
                .onAppear { pulse = true }

                VStack(spacing: 10) {
                    Text("TravelMatch")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Seferin, otelin senin partin.\nAynı yolda olduğun kişilerle tanış.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                VStack(spacing: 14) {
                    SignInWithAppleButton(.signIn) { request in
                        AuthService.shared.configure(request)
                    } onCompletion: { result in
                        Task {
                            do {
                                try await AuthService.shared.handle(result)
                            } catch {
                                appState.handleAuthError(error)
                            }
                        }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .neonGlow(Theme.violet, radius: 14)

                    if let error = appState.authErrorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(Theme.rose)
                    }
                }
                .padding(.horizontal, 24)

                // Metinler artık gerçekten okunabiliyor — eskiden yalnızca
                // "kabul etmiş olursun" yazıyordu ama hiçbir bağlantı yoktu.
                VStack(spacing: 6) {
                    Text("Devam ederek aşağıdakileri kabul etmiş olursun:")
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                    HStack(spacing: 14) {
                        Button("Kullanım Şartları") { showSartlar = true }
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.violet)
                        Button("Gizlilik Politikası") { showGizlilik = true }
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.violet)
                    }
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

                Spacer(minLength: 24)
            }
        }
        .sheet(isPresented: $showSartlar) {
            LegalView(belge: .sartlar)
        }
        .sheet(isPresented: $showGizlilik) {
            LegalView(belge: .gizlilik)
        }
    }
}

#Preview {
    LoginView().environmentObject(AppState())
}
