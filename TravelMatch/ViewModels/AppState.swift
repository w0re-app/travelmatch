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
    @Published var currentUser: AppUser = .mockCurrentUser
    @Published var authErrorMessage: String?

    // Trip / Verification
    @Published var currentTrip: Trip?
    @Published var currentTripDocId: String?
    @Published var verificationState: VerificationState = .idle
    @Published var routeStepCompleted: Bool = false

    // Discovery
    @Published var fellowTravelers: [TripFellowTraveler] = []

    // Matches & Chat
    @Published var matches: [MatchRecord] = []
    @Published var messagesByMatch: [String: [ChatMessage]] = [:]

    private let db = Firestore.firestore()
    private var authHandle: AuthStateDidChangeListenerHandle?

    init() {
        // Firebase oturum durumunu dinle (uygulama açılışında zaten girişliyse otomatik geç).
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { @MainActor in
                self.isLoggedIn = user != nil
                if let user {
                    await self.loadOrCreateUserProfile(uid: user.uid)
                    self.startListeningMatches(uid: user.uid)
                }
            }
        }
    }

    // MARK: - Auth

    /// LoginView, Apple ile giriş tamamlandığında (AuthService.handle sonrası) çağırır.
    /// Auth state listener zaten `isLoggedIn`'i güncelleyecek; bu yalnızca hata gösterimi içindir.
    func handleAuthError(_ error: Error) {
        authErrorMessage = error.localizedDescription
    }

    func signOut() {
        try? AuthService.shared.signOut()
        MatchService.shared.stopListening()
        TripService.shared.stopListening()
        currentTrip = nil
        verificationState = .idle
        fellowTravelers = []
        matches = []
    }

    private func loadOrCreateUserProfile(uid: String) async {
        let ref = db.collection("users").document(uid)
        if let existing = try? await ref.getDocument(as: UserDTO.self) {
            currentUser = AppUser(
                id: uid,
                fullName: existing.fullName,
                age: existing.age,
                bio: existing.bio,
                avatarSystemImage: "person.crop.circle.fill",
                intentTags: existing.intentTags.compactMap { IntentTag(rawValue: $0) },
                isIncognito: existing.isIncognito,
                blockedUids: existing.blockedUids
            )
        } else {
            // İlk giriş: taslak profil oluştur, kullanıcı sonra ProfileView'dan düzenler.
            let draft = UserDTO(fullName: "Yeni Kullanıcı", age: 18, bio: "", intentTags: [], isIncognito: false, fcmToken: nil, blockedUids: [], createdAt: nil)
            try? ref.setData(from: draft)
            currentUser = AppUser(id: uid, fullName: draft.fullName, age: draft.age, bio: draft.bio, avatarSystemImage: "person.crop.circle.fill", intentTags: [])
        }
    }

    // MARK: - Trip submission & real verification

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
                self.startListeningFellowTravelers(tripDocId: trip.id, locationIdentifier: trip.locationIdentifier)
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
        routeStepCompleted = false
        fellowTravelers = []
    }

    private func startListeningFellowTravelers(tripDocId: String, locationIdentifier: String) {
        let uid = currentUser.id
        let myBlockedUids = currentUser.blockedUids
        TripService.shared.listenFellowTravelers(
            tripDocId: tripDocId, locationIdentifier: locationIdentifier,
            currentUid: uid, myBlockedUids: myBlockedUids
        ) { [weak self] travelers in
            Task { @MainActor in
                self?.fellowTravelers = travelers
            }
        }
    }

    // MARK: - Profile

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

    // MARK: - Incognito

    func toggleIncognito() {
        currentUser.isIncognito.toggle()
        let uid = currentUser.id
        guard !uid.isEmpty else { return }
        db.collection("users").document(uid).updateData(["isIncognito": currentUser.isIncognito])
    }

    // MARK: - Matching

    func sendMatchRequest(to traveler: TripFellowTraveler) {
        guard let tripId = currentTripDocId else { return }
        if let index = fellowTravelers.firstIndex(where: { $0.id == traveler.id }) {
            fellowTravelers[index].matchStatus = .pendingSentByMe
        }
        Task {
            try? await MatchService.shared.sendMatchRequest(fromUid: self.currentUser.id, toUid: traveler.user.id, tripId: tripId)
        }
    }

    func respondToMatch(_ match: MatchRecord, accept: Bool) {
        Task {
            try? await MatchService.shared.respond(matchId: match.id, accept: accept)
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
                        intentTags: userDto.intentTags.compactMap { IntentTag(rawValue: $0) }
                    )
                    let sharedTrip = Trip(
                        id: tripDto.id ?? "", type: tripDto.type == "flight" ? .flight : .hotel,
                        referenceCode: "", locationIdentifier: tripDto.locationIdentifier,
                        startDate: tripDto.startDate.dateValue(), endDate: tripDto.endDate.dateValue(),
                        isVerified: tripDto.isVerified
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
                        expiresAt: dto.expiresAt?.dateValue() ?? Date(),
                        lastMessagePreview: nil, lastMessageDate: nil
                    ))
                }
                self.matches = records
            }
        }
    }

    // MARK: - Chat

    func startListeningMessages(for match: MatchRecord) {
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
                        type: type, content: dto.content, imageURL: dto.imageURL, imageAspectRatio: ratio,
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
            try? await ChatService.shared.sendMessage(matchId: match.id, senderUid: uid, content: trimmed)
        }
    }

    func sendImage(_ image: UIImage, in match: MatchRecord) {
        let uid = currentUser.id
        Task {
            try? await ChatService.shared.sendImage(matchId: match.id, senderUid: uid, image: image)
        }
    }

    // MARK: - Moderasyon (bildirme / engelleme)

    @Published var moderationErrorMessage: String?

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

    // MARK: - Güzergah (uğranacak noktalar)

    func updateTripRoute(_ waypoints: [RouteWaypoint]) {
        guard let tripId = currentTripDocId else { return }
        currentTrip?.plannedWaypoints = waypoints
        Task {
            try? await TripService.shared.updateRoute(tripId: tripId, waypoints: waypoints)
        }
    }
}
