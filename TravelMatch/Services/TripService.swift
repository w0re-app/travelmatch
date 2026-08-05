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
    ///
    /// Tarih çakışması: (onun başlangıcı <= benim bitişim) VE (onun bitişi >= benim başlangıcım).
    /// Firestore aynı sorguda iki farklı alanda aralık filtresine izin vermediği için
    /// ilk koşul sorguda, ikincisi client tarafında uygulanıyor.
    ///
    /// NOT: Bu sorgu için Firestore bileşik dizin ister. İlk çalıştırmada konsolda
    /// çıkan hata mesajındaki bağlantıya tıklayarak dizini tek tuşla oluşturabilirsin.
    func listenFellowTravelers(
        tripDocId: String,
        locationIdentifier: String,
        myStartDate: Date,
        myEndDate: Date,
        currentUid: String,
        myBlockedUids: [String],
        onUpdate: @escaping ([TripFellowTraveler]) -> Void
    ) {
        fellowTravelersListener?.remove()

        fellowTravelersListener = db.collection("trips")
            .whereField("locationIdentifier", isEqualTo: locationIdentifier)
            .whereField("startDate", isLessThanOrEqualTo: Timestamp(date: myEndDate))
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let docs = snapshot?.documents else {
                    if let error { print("Yol arkadaşı sorgusu başarısız: \(error.localizedDescription)") }
                    return
                }

                Task {
                    // Aynı kullanıcının birden fazla trip'i olabilir; her biri için
                    // ayrı okuma yapmamak adına users belgelerini önbelleğe alıyoruz.
                    var userCache: [String: UserDTO] = [:]
                    var results: [TripFellowTraveler] = []
                    // Aynı kişi aynı yer için birden fazla seyahat kaydetmiş
                    // olabilir (uygulamayı kapatıp tekrar eklediğinde). Listede
                    // bir kez görünsün.
                    var eklenenSahipler = Set<String>()

                    for doc in docs where doc.documentID != tripDocId {
                        guard let trip = try? doc.data(as: TripDTO.self) else { continue }

                        // Tarih çakışmasının ikinci yarısı.
                        guard trip.endDate.dateValue() >= myStartDate else { continue }

                        let ownerUid = trip.ownerUid
                        guard ownerUid != currentUid,
                              !myBlockedUids.contains(ownerUid),
                              !eklenenSahipler.contains(ownerUid) else { continue }

                        let userDto: UserDTO
                        if let cached = userCache[ownerUid] {
                            userDto = cached
                        } else {
                            guard let snap = try? await self.db.collection("users").document(ownerUid).getDocument(),
                                  let fetched = try? snap.data(as: UserDTO.self) else { continue }
                            userCache[ownerUid] = fetched
                            userDto = fetched
                        }

                        guard userDto.isIncognito == false,
                              !userDto.blockedUids.contains(currentUid) else { continue }

                        let user = AppUser(
                            id: userDto.id ?? ownerUid,
                            fullName: userDto.fullName,
                            age: userDto.age,
                            bio: userDto.bio,
                            avatarSystemImage: "person.crop.circle.fill",
                            intentTags: userDto.intentTags.compactMap { IntentTag(rawValue: $0) }
                        )

                        results.append(TripFellowTraveler(
                            id: doc.documentID,
                            user: user,
                            sharedTrip: Trip(
                                id: trip.id ?? doc.documentID,
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
                        eklenenSahipler.insert(ownerUid)
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

    /// Uygulama yeniden açıldığında kullanıcının devam eden seyahatini bulur.
    /// Yalnızca eşitlik sorgusu kullanıyor (bileşik dizin gerektirmesin diye),
    /// süre kontrolü ve sıralama client tarafında yapılıyor.
    func aktifSeyahatiGetir(uid: String) async -> (docId: String, trip: Trip)? {
        guard let snapshot = try? await db.collection("trips")
            .whereField("ownerUid", isEqualTo: uid)
            .getDocuments() else { return nil }

        let simdi = Date()
        let adaylar = snapshot.documents.compactMap { doc -> (String, TripDTO)? in
            guard let dto = try? doc.data(as: TripDTO.self) else { return nil }
            // Seyahat bitiminden 24 saat sonrasına kadar aktif sayılır.
            guard dto.endDate.dateValue().addingTimeInterval(24 * 60 * 60) > simdi else { return nil }
            return (doc.documentID, dto)
        }
        // Birden fazla varsa en yakın tarihli olanı al.
        guard let (docId, dto) = adaylar.min(by: { $0.1.startDate.dateValue() < $1.1.startDate.dateValue() })
        else { return nil }

        let trip = Trip(
            id: docId,
            type: dto.type == "flight" ? .flight : .hotel,
            referenceCode: dto.referenceCode,
            locationIdentifier: dto.locationIdentifier,
            startDate: dto.startDate.dateValue(),
            endDate: dto.endDate.dateValue(),
            isVerified: dto.isVerified,
            verificationMethod: TripVerificationMethod(rawValue: dto.verificationMethod) ?? .manual,
            plannedWaypoints: dto.plannedWaypoints
        )
        return (docId, trip)
    }

    func stopListening() {
        fellowTravelersListener?.remove()
    }
}
