import Foundation
import FirebaseFirestore

/// ⚠️ GEÇİCİ MİMARİ NOTU — bkz. TripService.swift başındaki açıklama.
/// Normalde `requestMatch` / `respondToMatch` Cloud Functions'ları üzerinden
/// yapılan mükerrer istek kontrolü ve engelleme kontrolü, Blaze aktif olmadığı
/// için burada client-side olarak yapılıyor — kötü niyetli bir client bu
/// kontrolleri atlayabilir (Cloud Functions geri gelince bu risk ortadan kalkar).
final class MatchService {

    static let shared = MatchService()
    private init() {}

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    enum MatchServiceError: LocalizedError {
        case alreadyRequested
        case blocked

        var errorDescription: String? {
            switch self {
            case .alreadyRequested: return "Bu kişiye zaten istek gönderdin."
            case .blocked: return "Bu kişiyle eşleşemezsin."
            }
        }
    }

    func sendMatchRequest(fromUid: String, toUid: String, tripId: String) async throws {
        // Engelleme kontrolü (her iki yön).
        let blockedByMe = try await db.collection("blocks").document("\(fromUid)_\(toUid)").getDocument()
        let blockedMe = try await db.collection("blocks").document("\(toUid)_\(fromUid)").getDocument()
        if blockedByMe.exists || blockedMe.exists {
            throw MatchServiceError.blocked
        }

        // Mükerrer istek kontrolü.
        let existing = try await db.collection("matches")
            .whereField("participants", arrayContains: fromUid)
            .whereField("tripId", isEqualTo: tripId)
            .getDocuments()
        if existing.documents.contains(where: { ($0.data()["participants"] as? [String])?.contains(toUid) == true }) {
            throw MatchServiceError.alreadyRequested
        }

        // expiresAt olmadan eşleşme "şu an sona ermiş" görünüyor ve temizlik
        // devreye girdiğinde anında siliniyor. Seyahatin bitişi + 24 saat.
        let tripDoc = try await db.collection("trips").document(tripId).getDocument()
        let tripEnd = (tripDoc.data()?["endDate"] as? Timestamp)?.dateValue() ?? Date()
        let expiresAt = tripEnd.addingTimeInterval(24 * 60 * 60)

        try await db.collection("matches").addDocument(data: [
            "tripId": tripId,
            "participants": [fromUid, toUid],
            "initiatedBy": fromUid,
            "status": "pending",
            "createdAt": FieldValue.serverTimestamp(),
            "expiresAt": Timestamp(date: expiresAt),
        ])
    }

    func respond(matchId: String, accept: Bool) async throws {
        try await db.collection("matches").document(matchId).updateData([
            "status": accept ? "accepted" : "rejected",
            "respondedAt": FieldValue.serverTimestamp(),
        ])
    }

    /// Giriş yapan kullanıcının dahil olduğu tüm eşleşmeleri gerçek zamanlı dinler.
    func listenMatches(uid: String, onUpdate: @escaping ([MatchDTO]) -> Void) {
        listener?.remove()
        listener = db.collection("matches")
            .whereField("participants", arrayContains: uid)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, _ in
                let matches = snapshot?.documents.compactMap { try? $0.data(as: MatchDTO.self) } ?? []
                onUpdate(matches)
            }
    }

    /// Hesap silme akışı: kullanıcının dahil olduğu tüm eşleşmeleri ve
    /// mesajlarını siler.
    func tumEslesmeleriSil(uid: String) async {
        guard let snapshot = try? await db.collection("matches")
            .whereField("participants", arrayContains: uid)
            .getDocuments() else { return }

        for doc in snapshot.documents {
            if let mesajlar = try? await doc.reference.collection("messages").getDocuments() {
                for m in mesajlar.documents { try? await m.reference.delete() }
            }
            try? await doc.reference.delete()
        }
    }

    func stopListening() {
        listener?.remove()
    }
}
