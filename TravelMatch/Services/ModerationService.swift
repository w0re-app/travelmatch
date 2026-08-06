import Foundation
import FirebaseFirestore

/// Bildirme ve engelleme. Cloud Functions kullanılmadığı için işlemler client
/// tarafında yapılıyor. Engelleme listesi `userSecrets/{uid}` içinde tutulur —
/// `users` dokümanı herkese açık okunduğu için orada duramaz.
final class ModerationService {

    static let shared = ModerationService()
    private init() {}

    private let db = Firestore.firestore()

    func reportUser(reportedUid: String, matchId: String?, reason: ReportReason, details: String, alsoBlock: Bool) async throws {
        var payload: [String: Any] = [
            "reporterUid": Auth_currentUid(),
            "reportedUid": reportedUid,
            "reason": reason.rawValue,
            "details": details,
            "status": "pending",
            "createdAt": FieldValue.serverTimestamp(),
        ]
        payload["matchId"] = matchId ?? NSNull()

        try await db.collection("reports").addDocument(data: payload)

        if alsoBlock {
            try await blockUser(reportedUid)
        }
    }

    func blockUser(_ blockedUid: String) async throws {
        let blockerUid = Auth_currentUid()
        guard !blockerUid.isEmpty else { return }

        let batch = db.batch()

        let blockRef = db.collection("blocks").document("\(blockerUid)_\(blockedUid)")
        batch.setData(["blockerUid": blockerUid, "blockedUid": blockedUid, "createdAt": FieldValue.serverTimestamp()], forDocument: blockRef)

        let secretRef = db.collection("userSecrets").document(blockerUid)
        batch.setData(["blockedUids": FieldValue.arrayUnion([blockedUid])],
                      forDocument: secretRef, merge: true)

        try await batch.commit()

        // Aradaki eşleşmeyi ayrıca "blocked" durumuna çek (batch içinde sorgu yapılamadığından ayrı adım).
        let matches = try await db.collection("matches")
            .whereField("participants", arrayContains: blockerUid)
            .getDocuments()
        let closeBatch = db.batch()
        for doc in matches.documents where (doc.data()["participants"] as? [String])?.contains(blockedUid) == true {
            closeBatch.updateData(["status": "blocked"], forDocument: doc.reference)
        }
        try await closeBatch.commit()
    }

    func unblockUser(_ blockedUid: String) async throws {
        let blockerUid = Auth_currentUid()
        guard !blockerUid.isEmpty else { return }

        try await db.collection("blocks").document("\(blockerUid)_\(blockedUid)").delete()
        try await db.collection("userSecrets").document(blockerUid).setData([
            "blockedUids": FieldValue.arrayRemove([blockedUid])
        ], merge: true)
    }

    private func Auth_currentUid() -> String {
        AuthService.shared.currentUid ?? ""
    }
}
