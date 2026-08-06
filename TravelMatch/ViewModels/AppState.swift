import Foundation
import UIKit
import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class AppState: ObservableObject {

    // Auth / Onboarding
    @Published var isLoggedIn: Bool = false
    @Published var currentUser: AppUser = .bosKullanici
    @Published var authErrorMessage: String?

    // Trip
    @Published var currentTrip: Trip?
    @Published var currentTripDocId: String?
    @Published var verificationState: VerificationState = .idle
    @Published var seyahatlerim: [(docId: String, trip: Trip)] = []

    // Discovery
    @Published var fellowTravelers: [TripFellowTraveler] = []

    // Profil fotoğrafı — değeri değişince AvatarView'lar yeniden yükler.
    @Published var avatarSurumu = UUID()
    @Published var avatarYukleniyor = false
    @Published var avatarHatasi: String?

    // Matches & Chat
    @Published var matches: [MatchRecord] = []
    @Published var matchErrorMessage: String?
    @Published var messagesByMatch: [String: [ChatMessage]] = [:]

    // Moderasyon / hesap
    @Published var moderationErrorMessage: String?
    @Published var hesapSiliniyor = false
    @Published var hesapSilmeHatasi: String?

    private let db = Firestore.firestore()
    private var authHandle: AuthStateDidChangeListenerHandle?

    init() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { @MainActor in
                self.isLoggedIn = user != nil
                if let user {
                    await self.loadOrCreateUserProfile(uid: user.uid)
                    self.startListeningMatches(uid: user.uid)
                    await self.seyahatleriYenile(uid: user.uid)
                } else {
                    self.yereliTemizle()
                }
            }
        }
    }

    // MARK: - Auth

    func handleAuthError(_ error: Error) {
        authErrorMessage = error.localizedDescription
    }

    func signOut() {
        try? AuthService.shared.signOut()
        yereliTemizle()
    }

    /// Oturum kapandığında bellekteki her şey gitmeli — aynı cihazda başka biri
    /// giriş yaparsa öncekinin verisini görmemeli.
    private func yereliTemizle() {
        MatchService.shared.stopListening()
        TripService.shared.stopListening()
        ChatService.shared.stopListening()
        currentUser = .bosKullanici
        currentTrip = nil
        currentTripDocId = nil
        verificationState = .idle
        seyahatlerim = []
        fellowTravelers = []
        matches = []
        messagesByMatch = [:]
        matchErrorMessage = nil
        moderationErrorMessage = nil
        avatarHatasi = nil
        avatarSurumu = UUID()
    }

    private func loadOrCreateUserProfile(uid: String) async {
        let ref = db.collection("users").document(uid)
        var engellenenler: [String] = []
        if let gizli = try? await db.collection("userSecrets").document(uid).getDocument(as: UserSecretDTO.self) {
            engellenenler = gizli.blockedUids
        }

        if let existing = try? await ref.getDocument(as: UserDTO.self) {
            currentUser = AppUser(
                id: uid,
                fullName: existing.fullName,
                age: existing.age,
                bio: existing.bio,
                avatarSystemImage: "person.crop.circle.fill",
                intentTags: existing.intentTags.compactMap { IntentTag(rawValue: $0) },
                isIncognito: existing.isIncognito,
                isVerified: existing.isVerified,
                blockedUids: engellenenler
            )
        } else {
            let draft = UserDTO(fullName: "Yeni Kullanıcı", age: 18, bio: "",
                                intentTags: [], isIncognito: false, isVerified: false, createdAt: nil)
            try? ref.setData(from: draft)
            currentUser = AppUser(id: uid, fullName: draft.fullName, age: draft.age, bio: draft.bio,
                                  avatarSystemImage: "person.crop.circle.fill", intentTags: [])
        }
    }

    // MARK: - Seyahatler

    func seyahatleriYenile(uid: String? = nil) async {
        let hedef = uid ?? currentUser.id
        guard !hedef.isEmpty else { return }
        seyahatlerim = await TripService.shared.seyahatlerim(uid: hedef)

        if currentTrip == nil,
           let aktif = seyahatlerim.first(where: { TripService.aktifMi($0.trip) }) {
            currentTrip = aktif.trip
            currentTripDocId = aktif.docId
            verificationState = .verified
            startListeningFellowTravelers(trip: aktif.trip)
        }
    }

    var aktifSeyahatler: [(docId: String, trip: Trip)] {
        seyahatlerim.filter { TripService.aktifMi($0.trip) }
    }

    var gecmisSeyahatler: [(docId: String, trip: Trip)] {
        seyahatlerim.filter { !TripService.aktifMi($0.trip) }
    }

    func submitTrip(
        type: TripType,
        referenceCode: String,
        locationIdentifier: String,
        startDate: Date,
        endDate: Date,
        verificationMethod: TripVerificationMethod = .manual,
        documentHash: String? = nil
    ) {
        let uid = currentUser.id
        guard !uid.isEmpty else { return }
        verificationState = .verifying

        Task {
            do {
                let trip = try await TripService.shared.submitTrip(
                    uid: uid, type: type, referenceCode: referenceCode,
                    locationIdentifier: locationIdentifier, startDate: startDate, endDate: endDate,
                    verificationMethod: verificationMethod, documentHash: documentHash
                )
                self.currentTrip = trip
                self.currentTripDocId = trip.id
                self.verificationState = .verified
                self.startListeningFellowTravelers(trip: trip)
                await self.seyahatleriYenile()

                // Belgeyle doğrulanmış bir seyahati olan kullanıcı "doğrulanmış"
                // rozetini hak eder. Rozetin bir karşılığı olsun diye burada
                // yazılıyor — varsayılan olarak herkes doğrulanmış sayılmıyor.
                if trip.verificationMethod == .document, self.currentUser.isVerified == false {
                    self.currentUser.isVerified = true
                    try? await self.db.collection("users").document(uid).updateData(["isVerified": true])
                }
            } catch {
                self.verificationState = .failed(error.localizedDescription)
            }
        }
    }

    func resetTrip() {
        TripService.shared.stopListening()
        currentTrip = nil
        currentTripDocId = nil
        verificationState = .idle
        fellowTravelers = []
    }

    /// Seyahati Firestore'dan tamamen siler (PNR kaydı dahil).
    func seyahatiSil(docId: String) {
        Task {
            do {
                try await TripService.shared.seyahatSil(tripId: docId)
                if currentTripDocId == docId { resetTrip() }
                await seyahatleriYenile()
            } catch {
                moderationErrorMessage = error.localizedDescription
            }
        }
    }

    func seyahatiSec(docId: String, trip: Trip) {
        currentTrip = trip
        currentTripDocId = docId
        verificationState = .verified
        startListeningFellowTravelers(trip: trip)
    }

    private func startListeningFellowTravelers(trip: Trip) {
        let uid = currentUser.id
        let myBlockedUids = currentUser.blockedUids
        TripService.shared.listenFellowTravelers(
            tripDocId: trip.id,
            locationIdentifier: trip.locationIdentifier,
            myStartDate: trip.startDate,
            myEndDate: trip.endDate,
            currentUid: uid,
            myBlockedUids: myBlockedUids
        ) { [weak self] travelers in
            Task { @MainActor in
                self?.fellowTravelers = travelers
            }
        }
    }

    // MARK: - Profil

    func updateProfile(fullName: String, age: Int, bio: String, intentTags: [IntentTag]) {
        currentUser.fullName = fullName
        currentUser.age = age
        currentUser.bio = bio
        currentUser.intentTags = intentTags

        let uid = currentUser.id
        guard !uid.isEmpty else { return }
        db.collection("users").document(uid).updateData([
            "fullName": fullName,
            "age": age,
            "bio": bio,
            "intentTags": intentTags.map(\.rawValue)
        ])
    }

    func uploadProfilePhoto(_ image: UIImage) {
        avatarYukleniyor = true
        avatarHatasi = nil
        Task {
            do {
                try await SupabaseDepo.ortak.profilFotografiYukle(image)
                self.avatarSurumu = UUID()
            } catch {
                self.avatarHatasi = error.localizedDescription
            }
            self.avatarYukleniyor = false
        }
    }

    func toggleIncognito() {
        currentUser.isIncognito.toggle()
        let uid = currentUser.id
        guard !uid.isEmpty else { return }
        db.collection("users").document(uid).updateData(["isIncognito": currentUser.isIncognito])
    }

    // MARK: - Eşleşme

    func sendMatchRequest(to traveler: TripFellowTraveler) {
        guard let tripId = currentTripDocId else {
            matchErrorMessage = "Önce bir seyahat eklemelisin."
            return
        }
        if let index = fellowTravelers.firstIndex(where: { $0.id == traveler.id }) {
            fellowTravelers[index].matchStatus = .pendingSentByMe
        }
        Task {
            do {
                try await MatchService.shared.sendMatchRequest(
                    fromUid: self.currentUser.id, toUid: traveler.user.id, tripId: tripId
                )
            } catch {
                if let index = self.fellowTravelers.firstIndex(where: { $0.id == traveler.id }) {
                    self.fellowTravelers[index].matchStatus = .none
                }
                self.matchErrorMessage = error.localizedDescription
            }
        }
    }

    func respondToMatch(_ match: MatchRecord, accept: Bool) {
        Task {
            do {
                try await MatchService.shared.respond(matchId: match.id, accept: accept)
            } catch {
                self.matchErrorMessage = error.localizedDescription
            }
        }
    }

    private func startListeningMatches(uid: String) {
        MatchService.shared.listenMatches(uid: uid) { [weak self] dtos in
            guard let self else { return }
            Task { @MainActor in
                var records: [MatchRecord] = []
                for dto in dtos {
                    guard let matchId = dto.id, dto.status != "blocked" else { continue }
                    let otherUid = dto.participants.first { $0 != uid } ?? ""
                    guard let userSnap = try? await self.db.collection("users").document(otherUid).getDocument(),
                          let userDto = try? userSnap.data(as: UserDTO.self),
                          let tripSnap = try? await self.db.collection("trips").document(dto.tripId).getDocument(),
                          let tripDto = try? tripSnap.data(as: TripDTO.self) else { continue }

                    let otherUser = AppUser(
                        id: otherUid, fullName: userDto.fullName, age: userDto.age, bio: userDto.bio,
                        avatarSystemImage: "person.crop.circle.fill",
                        intentTags: userDto.intentTags.compactMap { IntentTag(rawValue: $0) },
                        isVerified: userDto.isVerified
                    )
                    let sharedTrip = Trip(
                        id: tripDto.id ?? "", type: tripDto.type == "flight" ? .flight : .hotel,
                        referenceCode: "", locationIdentifier: tripDto.locationIdentifier,
                        startDate: tripDto.startDate.dateValue(), endDate: tripDto.endDate.dateValue(),
                        isVerified: tripDto.isVerified,
                        verificationMethod: TripVerificationMethod(rawValue: tripDto.verificationMethod) ?? .manual,
                        plannedWaypoints: tripDto.plannedWaypoints
                    )
                    let status: MatchStatus = {
                        switch dto.status {
                        case "accepted": return .accepted
                        case "rejected": return .rejected
                        default: return dto.initiatedBy == uid ? .pendingSentByMe : .pendingReceivedByMe
                        }
                    }()

                    records.append(MatchRecord(
                        id: matchId, otherUser: otherUser, sharedTrip: sharedTrip, status: status,
                        createdAt: dto.createdAt?.dateValue() ?? Date(),
                        expiresAt: dto.expiresAt?.dateValue() ?? sharedTrip.endDate.addingTimeInterval(24 * 60 * 60),
                        lastMessagePreview: nil, lastMessageDate: nil
                    ))
                }
                self.matches = records
            }
        }
    }

    // MARK: - Sohbet

    func startListeningMessages(for match: MatchRecord) {
        // Supabase üyelik kaydı — bu olmadan sohbet fotoğrafları RLS'e takılır.
        Task { await ChatService.shared.sohbeteBaglan(matchId: match.id) }

        ChatService.shared.listenMessages(matchId: match.id) { [weak self] dtos in
            Task { @MainActor in
                guard let self else { return }
                let uid = self.currentUser.id
                self.messagesByMatch[match.id] = dtos.map { dto in
                    let type: ChatMessageType = {
                        switch dto.type {
                        case "image": return .image
                        case "emoji": return .emoji
                        default: return .text
                        }
                    }()
                    let ratio: CGFloat? = {
                        guard let w = dto.imageWidth, let h = dto.imageHeight, h > 0 else { return nil }
                        return CGFloat(w / h)
                    }()
                    return ChatMessage(
                        id: dto.id ?? UUID().uuidString, matchId: match.id, isFromMe: dto.senderUid == uid,
                        type: type, content: dto.content, imageURL: dto.imagePath, imageAspectRatio: ratio,
                        sentAt: dto.sentAt?.dateValue() ?? Date()
                    )
                }
            }
        }
    }

    func messages(for match: MatchRecord) -> [ChatMessage] {
        messagesByMatch[match.id] ?? []
    }

    func sendMessage(_ text: String, in match: MatchRecord) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let uid = currentUser.id
        guard !trimmed.isEmpty else { return }
        Task {
            do {
                try await ChatService.shared.sendMessage(matchId: match.id, senderUid: uid, content: trimmed)
            } catch {
                // Sessiz başarısızlık kullanıcıya mesaj gitmiş gibi görünüyordu.
                self.matchErrorMessage = "Mesaj gönderilemedi: \(error.localizedDescription)"
            }
        }
    }

    func sendImage(_ image: UIImage, in match: MatchRecord) {
        let uid = currentUser.id
        Task {
            do {
                try await ChatService.shared.sendImage(matchId: match.id, senderUid: uid, image: image)
            } catch {
                self.matchErrorMessage = "Fotoğraf gönderilemedi: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Moderasyon

    func reportUser(_ uid: String, matchId: String?, reason: ReportReason, details: String, alsoBlock: Bool) {
        Task {
            do {
                try await ModerationService.shared.reportUser(
                    reportedUid: uid, matchId: matchId, reason: reason, details: details, alsoBlock: alsoBlock
                )
                if alsoBlock {
                    currentUser.blockedUids.append(uid)
                    fellowTravelers.removeAll { $0.user.id == uid }
                }
            } catch {
                moderationErrorMessage = error.localizedDescription
            }
        }
    }

    func blockUser(_ uid: String) {
        Task {
            do {
                try await ModerationService.shared.blockUser(uid)
                currentUser.blockedUids.append(uid)
                fellowTravelers.removeAll { $0.user.id == uid }
            } catch {
                moderationErrorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Güzergah

    func updateTripRoute(_ waypoints: [RouteWaypoint]) {
        guard let tripId = currentTripDocId else { return }
        currentTrip?.plannedWaypoints = waypoints
        Task {
            try? await TripService.shared.updateRoute(tripId: tripId, waypoints: waypoints)
        }
    }

    // MARK: - Hesap silme (App Store Review Guideline 5.1.1(v))

    /// Kullanıcının tüm verisini siler, sonra Firebase hesabını kapatır.
    /// `authorizationCode` Apple ile yeniden doğrulamadan gelir; token
    /// iptali için gerekli.
    func hesabiSil(authorizationCode: String?) async {
        let uid = currentUser.id
        guard !uid.isEmpty else { return }

        hesapSiliniyor = true
        hesapSilmeHatasi = nil

        // 1) Eşleşmeler ve mesajlar
        await MatchService.shared.tumEslesmeleriSil(uid: uid)

        // 2) Seyahatler ve PNR kayıtları
        await TripService.shared.tumSeyahatleriSil(uid: uid)

        // 3) Engelleme kayıtları
        if let bloklar = try? await db.collection("blocks")
            .whereField("blockerUid", isEqualTo: uid).getDocuments() {
            for doc in bloklar.documents { try? await doc.reference.delete() }
        }

        // 4) Profil fotoğrafı (Supabase)
        try? await SupabaseDepo.ortak.profilFotografiSil()

        // 5) Kullanıcı belgeleri
        try? await db.collection("userSecrets").document(uid).delete()
        try? await db.collection("users").document(uid).delete()

        // 6) Firebase hesabı + Apple token iptali
        do {
            try await AuthService.shared.deleteAccount(authorizationCode: authorizationCode)
            yereliTemizle()
        } catch {
            hesapSilmeHatasi = error.localizedDescription
        }

        hesapSiliniyor = false
    }
}
