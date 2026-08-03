import Foundation

struct AppUser: Identifiable, Hashable {
    let id: String
    var fullName: String
    var age: Int
    var bio: String
    var avatarSystemImage: String   // prototipte gerçek fotoğraf yerine SF Symbol kullanıyoruz
    var intentTags: [IntentTag]
    var isIncognito: Bool = false
    var isVerified: Bool = true
    var blockedUids: [String] = []  // bu kullanıcının engellediği kişiler (yalnızca kendi profilinde dolu gelir)

    static let mockCurrentUser = AppUser(
        id: UUID().uuidString,
        fullName: "Sen",
        age: 29,
        bio: "İstanbul merkezli, seyahat etmeyi seviyorum.",
        avatarSystemImage: "person.crop.circle.fill",
        intentTags: [.coffee, .cityTour]
    )
}

enum IntentTag: String, CaseIterable, Identifiable, Hashable {
    case coffee = "Kahve içelim"
    case cityTour = "Şehri birlikte gezelim"
    case networking = "İş networking'i"
    case chatOnly = "Sadece tanışmak/sohbet"
    case foodie = "Birlikte yemek"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .coffee: return "cup.and.saucer.fill"
        case .cityTour: return "map.fill"
        case .networking: return "briefcase.fill"
        case .chatOnly: return "bubble.left.and.bubble.right.fill"
        case .foodie: return "fork.knife"
        }
    }
}
