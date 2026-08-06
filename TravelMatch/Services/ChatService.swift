import Foundation
import UIKit
import FirebaseFirestore

/// Sohbet mesajları Firestore'da, fotoğraflar Supabase Storage'da.
/// (Firebase Storage Blaze planı gerektirdiği için kullanılmıyor.)
final class ChatService {

    static let shared = ChatService()
    private init() {}

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    enum ChatError: LocalizedError {
        case bosMesaj
        var errorDescription: String? { "Mesaj boş olamaz." }
    }

    /// Sohbet ekranı açıldığında bir kez çağrılmalı.
    /// Supabase'deki üyelik kaydı olmadan o sohbetin fotoğraflarına
    /// ne yazılabilir ne de okunabilir (RLS politikaları buna bakıyor).
    func sohbeteBaglan(matchId: String) async {
        do {
            try await SupabaseDepo.ortak.sohbeteKatil(sohbetId: matchId)
        } catch {
            // Üyelik kaydı başarısız olsa da metin mesajlaşması çalışmalı;
            // yalnızca fotoğraf gönderimi/gösterimi etkilenir.
            print("Supabase sohbet üyeliği kaydedilemedi: \(error.localizedDescription)")
        }
    }

    private func mesajlar(_ matchId: String) -> CollectionReference {
        db.collection("matches").document(matchId).collection("messages")
    }

    /// Client doğrudan yazar; Firestore kuralları yalnızca `status == accepted`
    /// olan eşleşmelerde mesaj eklenmesine izin verir (bkz. firestore.rules).
    ///
    /// ÖNEMLİ: `sentAt` mutlaka sunucu zaman damgasıyla yazılır. Codable ile
    /// `nil` gönderildiğinde alan belgeye hiç yazılmıyordu; dinleyici
    /// `.order(by: "sentAt")` kullandığı için Firestore o belgeleri sonuçtan
    /// dışlıyor ve mesaj hiç görünmüyordu.
    ///
    /// Yazma `await` ile bekleniyor — aksi halde izin hatası sessizce kaybolur.
    func sendMessage(matchId: String, senderUid: String, content: String) async throws {
        let metin = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !metin.isEmpty else { throw ChatError.bosMesaj }

        try await mesajlar(matchId).document().setData([
            "senderUid": senderUid,
            "type": Self.isEmojiOnly(metin) ? "emoji" : "text",
            "content": metin,
            "sentAt": FieldValue.serverTimestamp(),
        ])
    }

    /// Fotoğrafı Supabase Storage'a yükler, sonra mesaj dokümanını oluşturur.
    /// Firestore'a kalıcı bir URL değil, dosya YOLU yazılır — indirme adresi
    /// gösterim anında imzalı URL olarak üretilir (bkz. `fotografUrl`).
    func sendImage(matchId: String, senderUid: String, image: UIImage) async throws {
        // Sıkıştırma SupabaseDepo içinde yapılıyor (uzun kenar 1600 px, JPEG).
        let yol = try await SupabaseDepo.ortak.sohbetFotografiYukle(image, sohbetId: matchId)

        try await mesajlar(matchId).document().setData([
            "senderUid": senderUid,
            "type": "image",
            "content": "",
            "imagePath": yol,
            "imageWidth": Double(image.size.width),
            "imageHeight": Double(image.size.height),
            "sentAt": FieldValue.serverTimestamp(),
        ])
    }

    /// Mesajdaki yol için geçici (1 saat) indirme adresi üretir.
    func fotografUrl(for message: MessageDTO) async throws -> URL? {
        guard let yol = message.imagePath else { return nil }
        return try await SupabaseDepo.ortak.sohbetFotografiUrl(yol: yol)
    }

    func listenMessages(matchId: String, onUpdate: @escaping ([MessageDTO]) -> Void) {
        listener?.remove()
        listener = mesajlar(matchId)
            .order(by: "sentAt")
            .addSnapshotListener { snapshot, error in
                if let error {
                    print("Mesaj dinleyicisi başarısız: \(error.localizedDescription)")
                    return
                }
                let messages = snapshot?.documents.compactMap { try? $0.data(as: MessageDTO.self) } ?? []
                onUpdate(messages)
            }
    }

    func stopListening() {
        listener?.remove()
    }

    /// Mesaj yalnızca emoji karakter(ler)inden mi oluşuyor? (max 3 emoji —
    /// iMessage benzeri "büyük emoji" gösterimi için)
    static func isEmojiOnly(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 3 else { return false }
        return trimmed.unicodeScalars.allSatisfy { $0.properties.isEmojiPresentation || $0.properties.isEmoji }
    }
}
