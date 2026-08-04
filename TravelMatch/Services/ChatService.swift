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

    /// Client doğrudan yazar; Firestore kuralları yalnızca `status == accepted`
    /// olan eşleşmelerde mesaj eklenmesine izin verir (bkz. firestore.rules).
    func sendMessage(matchId: String, senderUid: String, content: String) async throws {
        let isEmojiOnly = Self.isEmojiOnly(content)
        let dto = MessageDTO(
            senderUid: senderUid,
            type: isEmojiOnly ? "emoji" : "text",
            content: content,
            imagePath: nil, imageWidth: nil, imageHeight: nil,
            sentAt: nil
        )
        _ = try db.collection("matches").document(matchId)
            .collection("messages")
            .addDocument(from: dto)
    }

    /// Fotoğrafı Supabase Storage'a yükler, sonra mesaj dokümanını oluşturur.
    /// Firestore'a kalıcı bir URL değil, dosya YOLU yazılır — indirme adresi
    /// gösterim anında imzalı URL olarak üretilir (bkz. `fotografUrl`).
    func sendImage(matchId: String, senderUid: String, image: UIImage) async throws {
        // Sıkıştırma SupabaseDepo içinde yapılıyor (uzun kenar 1600 px, JPEG).
        let yol = try await SupabaseDepo.ortak.sohbetFotografiYukle(image, sohbetId: matchId)

        let dto = MessageDTO(
            senderUid: senderUid,
            type: "image",
            content: "",
            imagePath: yol,
            imageWidth: image.size.width,
            imageHeight: image.size.height,
            sentAt: nil
        )
        _ = try db.collection("matches").document(matchId)
            .collection("messages")
            .addDocument(from: dto)
    }

    /// Mesajdaki yol için geçici (1 saat) indirme adresi üretir.
    /// Görsel gösterilirken çağrılır; süresi dolarsa yeniden çağrılmalı.
    func fotografUrl(for message: MessageDTO) async throws -> URL? {
        guard let yol = message.imagePath else { return nil }
        return try await SupabaseDepo.ortak.sohbetFotografiUrl(yol: yol)
    }

    func listenMessages(matchId: String, onUpdate: @escaping ([MessageDTO]) -> Void) {
        listener?.remove()
        listener = db.collection("matches").document(matchId)
            .collection("messages")
            .order(by: "sentAt")
            .addSnapshotListener { snapshot, _ in
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
