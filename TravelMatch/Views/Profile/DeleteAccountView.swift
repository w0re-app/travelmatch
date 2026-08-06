import SwiftUI
import AuthenticationServices

/// Hesap silme akışı — App Store Review Guideline 5.1.1(v) gereği uygulama
/// içinden başlatılabilmesi zorunlu. Yalnızca devre dışı bırakmak yeterli
/// sayılmıyor; hesap ve kişisel veri gerçekten siliniyor.
///
/// Apple ile Giriş kullanıldığı için silme öncesi yeniden kimlik doğrulama
/// yapılır; oradan gelen yetkilendirme koduyla Apple token'ları da iptal edilir.
struct DeleteAccountView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var onayMetni = ""
    private let beklenenOnay = "SİL"

    var body: some View {
        NavigationStack {
            ZStack {
                NightclubBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Label("Bu işlem geri alınamaz", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundStyle(Theme.rose)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Hesabını silersen şunlar kalıcı olarak kaldırılır:")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textPrimary)
                            madde("Profilin, fotoğrafın ve ilgi alanların")
                            madde("Tüm seyahatlerin ve rezervasyon kodların")
                            madde("Eşleşmelerin ve sohbet geçmişin")
                            madde("Engelleme kayıtların")
                        }
                        .padding(14)
                        .glassCard(cornerRadius: 16)

                        Text("Devam etmek için aşağıya \(beklenenOnay) yaz ve Apple ile kimliğini doğrula.")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)

                        TextField("", text: $onayMetni,
                                  prompt: Text(beklenenOnay).foregroundStyle(Theme.textTertiary))
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .foregroundStyle(Theme.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Theme.glassFill)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Theme.glassStroke, lineWidth: 1))

                        if appState.hesapSiliniyor {
                            HStack(spacing: 10) {
                                ProgressView().tint(Theme.rose)
                                Text("Hesabın siliniyor…").foregroundStyle(Theme.textSecondary)
                            }
                        } else {
                            SignInWithAppleButton(.continue) { request in
                                AuthService.shared.configureReauth(request)
                            } onCompletion: { result in
                                Task { await sil(result) }
                            }
                            .signInWithAppleButtonStyle(.white)
                            .frame(height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .disabled(onayMetni.uppercased() != beklenenOnay)
                            .opacity(onayMetni.uppercased() == beklenenOnay ? 1 : 0.4)
                        }

                        if let hata = appState.hesapSilmeHatasi {
                            Text(hata)
                                .font(.caption)
                                .foregroundStyle(Theme.rose)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Hesabı Sil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                        .disabled(appState.hesapSiliniyor)
                }
            }
        }
        .interactiveDismissDisabled(appState.hesapSiliniyor)
    }

    private func madde(_ metin: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "minus")
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
                .padding(.top, 4)
            Text(metin)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func sil(_ result: Result<ASAuthorization, Error>) async {
        do {
            let kod = try await AuthService.shared.reauthenticate(result)
            await appState.hesabiSil(authorizationCode: kod)
            if appState.hesapSilmeHatasi == nil { dismiss() }
        } catch {
            appState.hesapSilmeHatasi = error.localizedDescription
        }
    }
}

#Preview {
    DeleteAccountView().environmentObject(AppState()).preferredColorScheme(.dark)
}
