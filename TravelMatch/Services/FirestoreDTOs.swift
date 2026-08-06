import FirebaseFirestore

// Firestore koleksiyonlarıyla birebir eşleşen Codable modeller.
//
// GÜVENLİK NOTU: users/{uid} ve trips/{tripId} dokümanları giriş yapan HERKESE
// açık okunuyor (eşleşme kartında ad/yaş/bio, eşleşme sorgusunda uçuş kodu
// gerekiyor). Firestore alan bazlı izin veremediği için hassas alanlar bu
// dokümanlarda TUTULMAZ; yalnızca sahibinin erişebildiği ayrı koleksiyonlarda
// durur: userSecrets/{uid} ve tripSecrets/{tripId}.

struct UserDTO: Codable {
    @DocumentID var id: String?
    var fullName: String
    var age: Int
    var bio: String
    var intentTags: [String]
    var isIncognito: Bool
    var isVerified: Bool = false   // yalnızca belgeyle doğrulanmış seyahati olanda true
    var createdAt: Timestamp?
}

/// Yalnızca kullanıcının kendisinin okuyabildiği alanlar.
struct UserSecretDTO: Codable {
    var fcmToken: String?
    var blockedUids: [String] = []
}

struct TripDTO: Codable {
    @DocumentID var id: String?
    var ownerUid: String
    var type: String              // "flight" | "hotel"
    var locationIdentifier: String
    var startDate: Timestamp
    var endDate: Timestamp
    var isVerified: Bool
    var selfReported: Bool
    var verificationMethod: String  // "manual" | "document"
    var documentHash: String?
    var plannedWaypoints: [RouteWaypoint] = []
    var createdAt: Timestamp?
}

/// PNR / rezervasyon kodu — herkese açık trip dokümanında DURMAZ.
struct TripSecretDTO: Codable {
    var ownerUid: String
    var referenceCode: String
}

struct MatchDTO: Codable {
    @DocumentID var id: String?
    var tripId: String
    var participants: [String]
    var initiatedBy: String
    var status: String            // "pending" | "accepted" | "rejected" | "blocked"
    var createdAt: Timestamp?
    var expiresAt: Timestamp?
}

struct MessageDTO: Codable {
    @DocumentID var id: String?
    var senderUid: String
    var type: String        // "text" | "image" | "emoji"
    var content: String
    var imagePath: String?  // Supabase Storage yolu: {matchId}/{uid}-{uuid}.jpg
    var imageWidth: Double?
    var imageHeight: Double?
    var sentAt: Timestamp?
}
