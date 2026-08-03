import Foundation
import UIKit
import FirebaseFirestore
import FirebaseStorage

final class ChatService {

    static let shared = ChatService()
    private init() {}

    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private var listener: ListenerRegistration?

    /// Client doğrudan yazar; Firestore kuralları yalnızca `status == accepted`
    /// olan eşleşmelerde mesaj eklenmesine izin verir (bkz. firestore.rules).
    func sendMessage(matchId: String, senderUid: String, content: String) async throws {
        let isEmojiOnly = Self.isEmojiOnly(content)
        let dto = MessageDTO(
            senderUid: senderUid,
            type: isEmojiOnly ? "emoji" : "text",
            content: content,
            imageURL: nil, imageWidth: nil, imageHeight: nil,
            sentAt: nil
        )
        _ = try db.collection("matches").document(matchId)
            .collection("messages")
            .addDocument(from: dto)
    }

    /// Fotoğrafı Storage'a yükler, sonra mesaj dokümanını oluşturur.
    /// Storage yolu `chatImages/{matchId}/{uuid}.jpg` — kurallar yalnızca
    /// eşleşmenin iki tarafının erişimine izin verir (bkz. storage.rules).
    func sendImage(matchId: String, senderUid: String, image: UIImage) async throws {
        guard let jpegData = image.jpegData(compressionQuality: 0.72) else {
            throw NSError(domain: "ChatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Görsel sıkıştırılamadı."])
        }

        let fileName = "\(UUID().uuidString).jpg"
        let ref = storage.reference().child("chatImages/\(matchId)/\(fileName)")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await ref.putDataAsync(jpegData, metadata: metadata)
        let downloadURL = try await ref.downloadURL()

        let dto = MessageDTO(
            senderUid: senderUid,
            type: "image",
            content: "",
            imageURL: downloadURL.absoluteString,
            imageWidth: image.size.width,
            imageHeight: image.size.height,
            sentAt: nil
        )
        _ = try db.collection("matches").document(matchId)
            .collection("messages")
            .addDocument(from: dto)
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
