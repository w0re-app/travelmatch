import Foundation

enum MockData {

    static let sampleFlightTrip = Trip(
        id: UUID().uuidString,
        type: .flight,
        referenceCode: "PNR7XQ21",
        locationIdentifier: "TK-2144  IST → JFK",
        startDate: Date().addingTimeInterval(60 * 30),
        endDate: Date().addingTimeInterval(60 * 60 * 11),
        isVerified: true
    )

    static let sampleHotelTrip = Trip(
        id: UUID().uuidString,
        type: .hotel,
        referenceCode: "HTL-88231",
        locationIdentifier: "Hilton Bosphorus Istanbul",
        startDate: Date(),
        endDate: Date().addingTimeInterval(60 * 60 * 24 * 3),
        isVerified: true
    )

    static let sampleUsers: [AppUser] = [
        AppUser(id: UUID().uuidString, fullName: "Elif Y.", age: 27, bio: "Fotoğrafçılık ve kahve tutkunu.", avatarSystemImage: "person.crop.circle.fill", intentTags: [.coffee, .cityTour]),
        AppUser(id: UUID().uuidString, fullName: "Mert K.", age: 34, bio: "Girişimci, iş seyahatlerinde network kurmayı sever.", avatarSystemImage: "person.crop.circle.fill", intentTags: [.networking]),
        AppUser(id: UUID().uuidString, fullName: "Ayşe D.", age: 24, bio: "İlk defa yurt dışına çıkıyorum, heyecanlıyım!", avatarSystemImage: "person.crop.circle.fill", intentTags: [.chatOnly, .foodie]),
        AppUser(id: UUID().uuidString, fullName: "Burak S.", age: 31, bio: "Uzun uçuşlarda sohbet iyi gelir.", avatarSystemImage: "person.crop.circle.fill", intentTags: [.chatOnly]),
        AppUser(id: UUID().uuidString, fullName: "Zeynep A.", age: 29, bio: "Şehir kaşifi, yeni yerler keşfetmeyi seviyorum.", avatarSystemImage: "person.crop.circle.fill", intentTags: [.cityTour, .foodie]),
    ]

    static func fellowTravelers(for trip: Trip) -> [TripFellowTraveler] {
        sampleUsers.map {
            TripFellowTraveler(id: UUID().uuidString, user: $0, sharedTrip: trip, matchStatus: .none)
        }
    }

    static func sampleMatches() -> [MatchRecord] {
        let now = Date()
        return [
            MatchRecord(
                id: UUID().uuidString,
                otherUser: sampleUsers[0],
                sharedTrip: sampleFlightTrip,
                status: .accepted,
                createdAt: now.addingTimeInterval(-3600),
                expiresAt: sampleFlightTrip.endDate.addingTimeInterval(60 * 60 * 24),
                lastMessagePreview: "Kapıda görüşürüz o zaman 👋",
                lastMessageDate: now.addingTimeInterval(-600)
            ),
            MatchRecord(
                id: UUID().uuidString,
                otherUser: sampleUsers[1],
                sharedTrip: sampleHotelTrip,
                status: .pendingReceivedByMe,
                createdAt: now.addingTimeInterval(-1800),
                expiresAt: sampleHotelTrip.endDate.addingTimeInterval(60 * 60 * 24),
                lastMessagePreview: nil,
                lastMessageDate: nil
            )
        ]
    }

    static func sampleMessages(for matchId: String) -> [ChatMessage] {
        let now = Date()
        return [
            ChatMessage(id: UUID().uuidString, matchId: matchId, isFromMe: false, content: "Merhaba! Aynı uçuştayız galiba 😄", sentAt: now.addingTimeInterval(-3000)),
            ChatMessage(id: UUID().uuidString, matchId: matchId, isFromMe: true, content: "Evet aynen, hangi koltuktasın?", sentAt: now.addingTimeInterval(-2900)),
            ChatMessage(id: UUID().uuidString, matchId: matchId, isFromMe: false, content: "14A, sen?", sentAt: now.addingTimeInterval(-2800)),
            ChatMessage(id: UUID().uuidString, matchId: matchId, isFromMe: true, content: "14C, komşuymuşuz o zaman!", sentAt: now.addingTimeInterval(-2700)),
            ChatMessage(id: UUID().uuidString, matchId: matchId, isFromMe: false, content: "Kapıda görüşürüz o zaman 👋", sentAt: now.addingTimeInterval(-600)),
        ]
    }
}
