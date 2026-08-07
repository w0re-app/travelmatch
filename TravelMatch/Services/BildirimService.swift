import Foundation
import FirebaseAuth

/// Uygulama içi aksiyonlardan sonra karşı tarafa push bildirimi tetikler.
///
/// Bildirimi uygulama göndermez — Supabase Edge Function gönderir. Sebep:
/// FCM'e mesaj yollamak servis hesabı anahtarı ister, o da istemciye
/// konulamaz. Buradan giden tek şey Firebase kimlik token'ı; fonksiyon onu
/// doğrulayıp gönderenin gerçekten o eşleşmenin tarafı olduğunu kontrol ediyor.
///
/// Bildirim gönderilememesi akışı durdurmaz — mesaj/istek zaten Firestore'a
/// yazılmış olur, yalnızca karşı taraf anlık uyarı almaz.
enum BildirimService {

    enum Tur: String {
        case eslesmeIstegi
        case eslesmeKabul
        case yeniMesaj
    }

    /// SupabaseDepo'daki proje adresiyle aynı olmalı.
    private static let fonksiyonURL = URL(
        string: "https://jrrekhuftisfbflsabub.supabase.co/functions/v1/bildirim-gonder"
    )!

    static func gonder(tur: Tur, hedefUid: String, matchId: String) async {
        guard !hedefUid.isEmpty, !matchId.isEmpty else { return }
        guard let idToken = try? await Auth.auth().currentUser?.getIDToken() else { return }

        var istek = URLRequest(url: fonksiyonURL)
        istek.httpMethod = "POST"
        istek.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        istek.setValue("application/json", forHTTPHeaderField: "Content-Type")
        istek.httpBody = try? JSONSerialization.data(withJSONObject: [
            "hedefUid": hedefUid,
            "matchId": matchId,
            "tur": tur.rawValue,
        ])

        do {
            let (veri, yanit) = try await URLSession.shared.data(for: istek)
            if let http = yanit as? HTTPURLResponse, http.statusCode >= 400 {
                let govde = String(data: veri, encoding: .utf8) ?? ""
                print("Bildirim gönderilemedi (\(http.statusCode)): \(govde)")
            }
        } catch {
            print("Bildirim isteği başarısız: \(error.localizedDescription)")
        }
    }
}
