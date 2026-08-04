import FirebaseFirestore

// Firestore koleksiyonlarıyla birebir eşleşen Codable modeller.
// Not: @DocumentID kullanımı için FirebaseFirestoreSwift (veya SDK 10+'da
// FirebaseFirestore'un kendisi) proje hedefine eklenmiş olmalı.

struct UserDTO: Codable {
    @DocumentID var id: String?
    var fullName: String
    var age: Int
    var bio: String
    var intentTags: [String]
    var isIncognito: Bool
    var fcmToken: String?
    var blockedUids: [String] = []
    var createdAt: Timestamp?
}

struct TripDTO: Codable {
    @DocumentID var id: String?
    var ownerUid: String
    var type: String              // "flight" | "hotel"
    var referenceCode: String     // PNR / rezervasyon no (yalnızca sahibi görür - client filtreler)
    var locationIdentifier: String
    var startDate: Timestamp
    var endDate: Timestamp
    var isVerified: Bool
    var selfReported: Bool        // otel için her zaman true, uçuş için API doğrulaması varsa false
    var verificationMethod: String  // "manual" | "document"
    var documentHash: String?       // fotoğrafla doğrulamada tekillik kontrolü için (bkz. documentClaims)
    var plannedWaypoints: [RouteWaypoint] = []
    var createdAt: Timestamp?
}

struct MatchDTO: Codable {
    @DocumentID var id: String?
    var tripId: String
    var participants: [String]
    var initiatedBy: String
    var status: String            // "pending" | "accepted" | "rejected"
    var createdAt: Timestamp?
    var expiresAt: Timestamp?
}

struct MessageDTO: Codable {
    @DocumentID var id: String?
    var senderUid: String
    var type: String        // "text" | "image" | "emoji"
    var content: String     // metin içeriği ya da emoji karakteri (görsel mesajlarda boş olabilir)
    var imagePath: String?  // Supabase Storage yolu: {matchId}/{uid}-{uuid}.jpg
                            // (kalıcı URL değil — indirme adresi imzalı olarak üretilir)
    var imageWidth: Double?
    var imageHeight: Double?
    var sentAt: Timestamp?
}
