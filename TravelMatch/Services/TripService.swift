import Foundation
import FirebaseFirestore

/// ⚠️ GEÇİCİ MİMARİ NOTU
/// Bu servis normalde `submitTrip` Cloud Function'ını çağırıyordu (bkz. functions/index.js).
/// Blaze faturalandırma planı henüz aktif olmadığından (Cloud Functions Spark planda
/// çalışmıyor), bu dosya doğrudan Firestore'a yazacak şekilde geçici olarak değiştirildi.
/// Blaze aktif olduğunda: `firebase deploy --only functions` çalıştır, sonra bu dosyayı
/// önceki (Cloud Function çağıran) haline geri al — git geçmişinde duruyor.
///
/// Kaybedilen sunucu-taraflı garantiler (geçici olarak client'a güveniyoruz):
/// - Uçuş gerçeklik kontrolü (AviationStack) artık yapılmıyor — API anahtarı client'ta
///   güvenle tutulamayacağından, uçuş seyahatleri artık yalnızca biniş kartı taranarak
///   (belge doğrulaması) "doğrulanmış" sayılabiliyor; elle giriş her zaman `isVerified = false`.
final class TripService {

    static let shared = TripService()
    private init() {}

    private let db = Firestore.firestore()
    private var fellowTravelersListener: ListenerRegistration?

    enum TripServiceError: LocalizedError {
        case documentAlreadyUsed
        case server(String)

        var errorDescription: String? {
            switch self {
            case .documentAlreadyUsed:
                return "Bu belge/biniş kartı daha önce başka bir hesap tarafından kullanılmış."
            case .server(let message):
                return message
            }
        }
    }

    func submitTrip(
        uid: String,
        type: TripType,
        referenceCode: String,
        locationIdentifier: String,
        startDate: Date,
        endDate: Date,
        verificationMethod: TripVerificationMethod,
        documentHash: String?
    ) async throws -> Trip {

        // Belge tekilliği kontrolü — Cloud Function yerine doğrudan Firestore transaction.
        // Güvenlik, "documentClaims/{hash}" üzerindeki firestore.rules'daki
        // `allow update: if false` kuralıyla sağlanıyor: bir kez oluşturulan kayıt
        // hiçbir client tarafından üzerine yazılamaz.
        if let documentHash {
            let claimRef = db.collection("documentClaims").document(documentHash)
            do {
                try await db.runTransaction { transaction, errorPointer in
                    let snapshot: DocumentSnapshot
                    do {
                        snapshot = try transaction.getDocument(claimRef)
                    } catch {
                        errorPointer?.pointee = error as NSError
                        return nil
                    }
                    if snapshot.exists, let ownerUid = snapshot.data()?["uid"] as? String, ownerUid != uid {
                        errorPointer?.pointee = NSError(domain: "TripService", code: 409)
                        return nil
                    }
                    if !snapshot.exists {
                        transaction.setData([
                            "uid": uid, "tripType": type == .flight ? "flight" : "hotel",
                            "createdAt": FieldValue.serverTimestamp(),
                        ], forDocument: claimRef)
                    }
                    return nil
                }
            } catch {
                throw TripServiceError.documentAlreadyUsed
            }
        }

        // Uçuş gerçeklik kontrolü (AviationStack) Cloud Function olmadan güvenle
        // yapılamıyor — bu yüzden yalnızca belge (biniş kartı) doğrulamasıyla gelen
        // uçuşlar "doğrulanmış" sayılıyor. Blaze'e geçilince bu satır kaldırılıp
        // gerçek API kontrolü geri gelecek.
        let isVerified = verificationMethod == .document

        let dto = TripDTO(
            ownerUid: uid,
            type: type == .flight ? "flight" : "hotel",
            referenceCode: referenceCode,
            locationIdentifier: locationIdentifier,
            startDate: Timestamp(date: startDate),
            endDate: Timestamp(date: endDate),
            isVerified: isVerified,
            selfReported: verificationMethod != .document,
            verificationMethod: verificationMethod.rawValue,
            documentHash: documentHash,
            plannedWaypoints: [],
            createdAt: nil
        )

        let ref = try db.collection("trips").addDocument(from: dto)

        return Trip(
            id: ref.documentID, type: type, referenceCode: referenceCode,
            locationIdentifier: locationIdentifier, startDate: startDate, endDate: endDate,
            isVerified: isVerified, verificationMethod: verificationMethod
        )
    }

    /// Aynı `locationIdentifier` + tarih aralığını paylaşan, gizli modda olmayan
    /// ve birbirini engellememiş diğer kullanıcıları gerçek zamanlı dinler.
    func listenFellowTravelers(tripDocId: String, locationIdentifier: String, currentUid: String, myBlockedUids: [String], onUpdate: @escaping ([TripFellowTraveler]) -> Void) {
        fellowTravelersListener?.remove()

        fellowTravelersListener = db.collection("trips")
            .whereField("locationIdentifier", isEqualTo: locationIdentifier)
            .addSnapshotListener { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                Task {
                    var results: [TripFellowTraveler] = []
                    for doc in docs where doc.documentID != tripDocId {
                        guard let trip = try? doc.data(as: TripDTO.self),
                              let ownerUid = trip.ownerUid as String?,
                              ownerUid != currentUid,
                              !myBlockedUids.contains(ownerUid),
                              let userSnap = try? await self.db.collection("users").document(ownerUid).getDocument(),
                              let userDto = try? userSnap.data(as: UserDTO.self),
                              userDto.isIncognito == false,
                              !userDto.blockedUids.contains(currentUid) else { continue }

                        let user = AppUser(
                            id: userDto.id ?? UUID().uuidString,
                            fullName: userDto.fullName,
                            age: userDto.age,
                            bio: userDto.bio,
                            avatarSystemImage: "person.crop.circle.fill",
                            intentTags: userDto.intentTags.compactMap { IntentTag(rawValue: $0) }
                        )
                        results.append(TripFellowTraveler(
                            id: UUID().uuidString,
                            user: user,
                            sharedTrip: Trip(
                                id: trip.id ?? "",
                                type: trip.type == "flight" ? .flight : .hotel,
                                referenceCode: "",
                                locationIdentifier: trip.locationIdentifier,
                                startDate: trip.startDate.dateValue(),
                                endDate: trip.endDate.dateValue(),
                                isVerified: trip.isVerified,
                                verificationMethod: TripVerificationMethod(rawValue: trip.verificationMethod) ?? .manual,
                                plannedWaypoints: trip.plannedWaypoints
                            ),
                            matchStatus: .none
                        ))
                    }
                    onUpdate(results)
                }
            }
    }

    /// Kullanıcının bu seyahatte uğramayı planladığı noktaları günceller.
    /// GEÇİCİ: Cloud Function yerine doğrudan yazma — firestore.rules yalnızca
    /// trip sahibinin kendi trip dokümanını güncelleyebilmesine izin veriyor.
    func updateRoute(tripId: String, waypoints: [RouteWaypoint]) async throws {
        let waypointMaps = waypoints.map {
            [
                "name": $0.name, "district": $0.district, "province": $0.province,
                "category": $0.category.rawValue, "popularity": $0.popularity,
            ] as [String: Any]
        }
        try await db.collection("trips").document(tripId).updateData(["plannedWaypoints": waypointMaps])
    }

    func stopListening() {
        fellowTravelersListener?.remove()
    }
}
