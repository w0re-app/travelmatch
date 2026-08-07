import Foundation
import FirebaseFirestore

/// Seyahat oluşturma, yol arkadaşı bulma ve seyahat geçmişi.
///
/// MİMARİ NOTU: Cloud Functions kullanılmıyor (Blaze planı açılamadı), client
/// doğrudan Firestore'a yazıyor. Bunun iki sonucu var:
///  - Uçuş gerçeklik kontrolü (AviationStack) yapılamıyor; yalnızca biniş kartı
///    taranarak doğrulanan seyahatler "doğrulanmış" sayılıyor.
///  - PNR / rezervasyon kodu herkese açık `trips` dokümanında tutulamaz
///    (bkz. firestore.rules) — `tripSecrets/{tripId}` koleksiyonunda durur.
final class TripService {

    static let shared = TripService()
    private init() {}

    private let db = Firestore.firestore()
    private var fellowTravelersListener: ListenerRegistration?

    enum TripServiceError: LocalizedError {
        case documentAlreadyUsed
        case eksikBilgi(String)

        var errorDescription: String? {
            switch self {
            case .documentAlreadyUsed:
                return "Bu belge/biniş kartı daha önce başka bir hesap tarafından kullanılmış."
            case .eksikBilgi(let mesaj):
                return mesaj
            }
        }
    }

    // MARK: - Seyahat oluşturma

    func submitTrip(
        uid: String,
        type: TripType,
        referenceCode: String,
        locationIdentifier: String,
        startDate: Date,
        endDate: Date,
        il: String?,
        ilce: String?,
        verificationMethod: TripVerificationMethod,
        documentHash: String?
    ) async throws -> Trip {

        let yer = locationIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !yer.isEmpty else {
            throw TripServiceError.eksikBilgi(
                type == .flight ? "Sefer kodunu girmelisin." : "Otel adını girmelisin.")
        }
        guard endDate > startDate else {
            throw TripServiceError.eksikBilgi("Bitiş tarihi başlangıçtan sonra olmalı.")
        }

        // Belge tekilliği — bir kez yazılan kayıt kurallar gereği güncellenemez,
        // yani aynı biniş kartı ikinci bir hesaba geçemez.
        if let documentHash {
            let claimRef = db.collection("documentClaims").document(documentHash)
            do {
                _ = try await db.runTransaction { transaction, errorPointer in
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
                            "uid": uid,
                            "tripType": type == .flight ? "flight" : "hotel",
                            "createdAt": FieldValue.serverTimestamp(),
                        ], forDocument: claimRef)
                    }
                    return nil
                }
            } catch {
                throw TripServiceError.documentAlreadyUsed
            }
        }

        let isVerified = verificationMethod == .document

        // Aynı yer için hâlâ aktif bir seyahat varsa yenisini AÇMA — tarihlerini
        // güncelle. Aksi halde uygulamayı her açıp seyahat girdiğinde yeni bir
        // doküman oluşuyor ve karşı taraf seni listede birden çok kez görüyor.
        if let mevcut = await mevcutAktifSeyahat(uid: uid, locationIdentifier: yer) {
            var guncel: [String: Any] = [
                "startDate": Timestamp(date: startDate),
                "endDate": Timestamp(date: endDate),
            ]
            if let il { guncel["il"] = il }
            if let ilce { guncel["ilce"] = ilce }
            try await db.collection("trips").document(mevcut).updateData(guncel)
            try? await yaziReferansKodu(tripId: mevcut, uid: uid, referenceCode: referenceCode)
            return Trip(
                id: mevcut, type: type, referenceCode: referenceCode,
                locationIdentifier: yer, startDate: startDate, endDate: endDate,
                isVerified: isVerified, verificationMethod: verificationMethod
            )
        }

        let dto = TripDTO(
            ownerUid: uid,
            type: type == .flight ? "flight" : "hotel",
            locationIdentifier: yer,
            il: il,
            ilce: ilce,
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
        try? await yaziReferansKodu(tripId: ref.documentID, uid: uid, referenceCode: referenceCode)

        return Trip(
            id: ref.documentID, type: type, referenceCode: referenceCode,
            locationIdentifier: yer, startDate: startDate, endDate: endDate,
            isVerified: isVerified, verificationMethod: verificationMethod
        )
    }

    /// PNR / rezervasyon kodunu yalnızca sahibinin okuyabildiği koleksiyona yazar.
    private func yaziReferansKodu(tripId: String, uid: String, referenceCode: String) async throws {
        let kod = referenceCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !kod.isEmpty else { return }
        // setData(from:) senkron ve throwing — await gerekmiyor.
        try db.collection("tripSecrets").document(tripId)
            .setData(from: TripSecretDTO(ownerUid: uid, referenceCode: kod))
    }

    func referansKodu(tripId: String) async -> String {
        guard let snap = try? await db.collection("tripSecrets").document(tripId).getDocument(),
              let dto = try? snap.data(as: TripSecretDTO.self) else { return "" }
        return dto.referenceCode
    }

    private func mevcutAktifSeyahat(uid: String, locationIdentifier: String) async -> String? {
        guard let snapshot = try? await db.collection("trips")
            .whereField("ownerUid", isEqualTo: uid)
            .getDocuments() else { return nil }

        let simdi = Date()
        return snapshot.documents.first { doc in
            guard let dto = try? doc.data(as: TripDTO.self) else { return false }
            return dto.locationIdentifier == locationIdentifier
                && dto.endDate.dateValue().addingTimeInterval(24 * 60 * 60) > simdi
        }?.documentID
    }

    // MARK: - Otel önerileri

    /// Seçilen ildeki otel adlarını, daha önce başka kullanıcıların girdiği
    /// kayıtlardan toplar. Elimizde hazır bir otel veri seti olmadığı için
    /// liste kullanımla birlikte büyür; aynı zamanda yazım farklarından doğan
    /// eşleşme kayıplarını da önler (kullanıcı listeden seçince birebir aynı
    /// metin kaydedilir).
    ///
    /// Yalnızca eşitlik sorgusu kullanır — bileşik dizin gerekmez.
    func otelOnerileri(il: String) async -> [String] {
        guard let snapshot = try? await db.collection("trips")
            .whereField("il", isEqualTo: il)
            .getDocuments() else { return [] }

        var adlar: [String: Int] = [:]
        for doc in snapshot.documents {
            guard let dto = try? doc.data(as: TripDTO.self), dto.type == "hotel" else { continue }
            let ad = dto.locationIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !ad.isEmpty else { continue }
            adlar[ad, default: 0] += 1
        }
        // Çok kullanılan isimler üstte.
        return adlar.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
                    .map(\.key)
    }

    // MARK: - Yol arkadaşları

    /// Aynı `locationIdentifier` + tarih aralığını paylaşan, gizli modda olmayan
    /// ve birbirini engellememiş kullanıcıları gerçek zamanlı dinler.
    ///
    /// Tarih çakışması: (onun başlangıcı <= benim bitişim) VE (onun bitişi >= benim başlangıcım).
    /// Firestore aynı sorguda iki farklı alanda aralık filtresine izin vermediği
    /// için ilk koşul sorguda, ikincisi client tarafında.
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
                    var userCache: [String: UserDTO] = [:]
                    var beniEngelleyenler = Set<String>()
                    var kontrolEdilenler = Set<String>()
                    var results: [TripFellowTraveler] = []
                    // Aynı kişi aynı yer için birden fazla kayıt açmış olabilir;
                    // listede bir kez görünsün.
                    var eklenenSahipler = Set<String>()

                    for doc in docs where doc.documentID != tripDocId {
                        guard let trip = try? doc.data(as: TripDTO.self) else { continue }
                        guard trip.endDate.dateValue() >= myStartDate else { continue }

                        let ownerUid = trip.ownerUid
                        guard ownerUid != currentUid,
                              !myBlockedUids.contains(ownerUid),
                              !eklenenSahipler.contains(ownerUid) else { continue }

                        // "O beni engellemiş mi?" — engelleme listesi artık herkese
                        // açık değil (userSecrets), bu yüzden blocks kaydına bakıyoruz.
                        if !kontrolEdilenler.contains(ownerUid) {
                            kontrolEdilenler.insert(ownerUid)
                            if let blok = try? await self.db.collection("blocks")
                                .document("\(ownerUid)_\(currentUid)").getDocument(), blok.exists {
                                beniEngelleyenler.insert(ownerUid)
                            }
                        }
                        guard !beniEngelleyenler.contains(ownerUid) else { continue }

                        let userDto: UserDTO
                        if let cached = userCache[ownerUid] {
                            userDto = cached
                        } else {
                            guard let snap = try? await self.db.collection("users").document(ownerUid).getDocument(),
                                  let fetched = try? snap.data(as: UserDTO.self) else { continue }
                            userCache[ownerUid] = fetched
                            userDto = fetched
                        }

                        guard userDto.isIncognito == false else { continue }

                        let user = AppUser(
                            id: userDto.id ?? ownerUid,
                            fullName: userDto.fullName,
                            age: userDto.age,
                            bio: userDto.bio,
                            avatarSystemImage: "person.crop.circle.fill",
                            intentTags: userDto.intentTags.compactMap { IntentTag(rawValue: $0) },
                            isVerified: userDto.isVerified
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

    // MARK: - Güzergah

    func updateRoute(tripId: String, waypoints: [RouteWaypoint]) async throws {
        let waypointMaps = waypoints.map {
            [
                "name": $0.name, "district": $0.district, "province": $0.province,
                "category": $0.category.rawValue, "popularity": $0.popularity,
            ] as [String: Any]
        }
        try await db.collection("trips").document(tripId).updateData(["plannedWaypoints": waypointMaps])
    }

    // MARK: - Seyahat listesi

    /// Kullanıcının tüm seyahatleri, yeniden eskiye. Ana sayfadaki geçmiş listesi
    /// ve aktif seyahat tespiti bunu kullanır.
    func seyahatlerim(uid: String) async -> [(docId: String, trip: Trip)] {
        guard let snapshot = try? await db.collection("trips")
            .whereField("ownerUid", isEqualTo: uid)
            .getDocuments() else { return [] }

        return snapshot.documents
            .compactMap { doc -> (String, Trip)? in
                guard let dto = try? doc.data(as: TripDTO.self) else { return nil }
                return (doc.documentID, Trip(
                    id: doc.documentID,
                    type: dto.type == "flight" ? .flight : .hotel,
                    referenceCode: "",
                    locationIdentifier: dto.locationIdentifier,
                    startDate: dto.startDate.dateValue(),
                    endDate: dto.endDate.dateValue(),
                    isVerified: dto.isVerified,
                    verificationMethod: TripVerificationMethod(rawValue: dto.verificationMethod) ?? .manual,
                    plannedWaypoints: dto.plannedWaypoints
                ))
            }
            .sorted { $0.1.startDate > $1.1.startDate }
    }

    /// Bitişinden 24 saat geçmemiş seyahat "aktif" sayılır.
    static func aktifMi(_ trip: Trip) -> Bool {
        trip.endDate.addingTimeInterval(24 * 60 * 60) > Date()
    }

    func aktifSeyahatiGetir(uid: String) async -> (docId: String, trip: Trip)? {
        await seyahatlerim(uid: uid)
            .filter { Self.aktifMi($0.trip) }
            .min { $0.trip.startDate < $1.trip.startDate }
    }

    // MARK: - Silme (hesap silme akışı ve kullanıcı isteği)

    func seyahatSil(tripId: String) async throws {
        try? await db.collection("tripSecrets").document(tripId).delete()
        try await db.collection("trips").document(tripId).delete()
    }

    func tumSeyahatleriSil(uid: String) async {
        for (docId, _) in await seyahatlerim(uid: uid) {
            try? await seyahatSil(tripId: docId)
        }
    }

    func stopListening() {
        fellowTravelersListener?.remove()
    }
}
