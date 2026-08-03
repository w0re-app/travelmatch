import Foundation
import FirebaseFirestore

/// ⚠️ GEÇİCİ MİMARİ NOTU — bkz. TripService.swift başındaki açıklama.
/// Normalde `reportUser` / `blockUser` / `unblockUser` Cloud Functions'ları
/// üzerinden yapılan işlemler burada doğrudan Firestore batch/transaction ile
/// yapılıyor. `users/{uid}.blockedUids` alanını client artık doğrudan
/// değiştirebiliyor (firestore.rules bu geçiş süresince gevşetildi — bkz. dosya).
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

        let userRef = db.collection("users").document(blockerUid)
        batch.updateData(["blockedUids": FieldValue.arrayUnion([blockedUid])], forDocument: userRef)

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
        try await db.collection("users").document(blockerUid).updateData([
            "blockedUids": FieldValue.arrayRemove([blockedUid])
        ])
    }

    private func Auth_currentUid() -> String {
        AuthService.shared.currentUid ?? ""
    }
}
