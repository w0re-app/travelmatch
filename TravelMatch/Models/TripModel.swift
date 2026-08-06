import Foundation

enum TripType: String, CaseIterable, Identifiable {
    case flight = "Uçuş"
    case hotel = "Otel"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .flight: return "airplane"
        case .hotel: return "building.2.fill"
        }
    }
}

enum VerificationState: Equatable {
    case idle
    case verifying
    case verified
    case failed(String)
}

/// Seyahatin nasıl doğrulandığı — dolandırıcılık/mükerrer kullanım analizinde
/// ve kullanıcıya güven rozeti göstermede kullanılır.
enum TripVerificationMethod: String {
    case manual              // kullanıcı bilgileri elle girdi
    case document            // biniş kartı/rezervasyon fotoğrafı tarandı ve sunucuda tekillik kontrolünden geçti
}

struct Trip: Identifiable, Hashable {
    let id: String
    var type: TripType
    var referenceCode: String        // PNR veya rezervasyon kodu
    var locationIdentifier: String   // Örn: "TK-2144 IST → JFK" veya "Hilton Bosphorus Istanbul"
    var startDate: Date
    var endDate: Date
    var isVerified: Bool
    var verificationMethod: TripVerificationMethod = .manual
    var plannedWaypoints: [RouteWaypoint] = []   // uğranacak plaj/köy/kasaba vb. duraklar

    static func == (lhs: Trip, rhs: Trip) -> Bool { lhs.id == rhs.id }
}

enum WaypointCategory: String, Codable, CaseIterable {
    case beach = "Plaj"
    case cove = "Koy"
    case island = "Ada"
    case village = "Köy"
    case town = "Kasaba"
    case historic = "Tarihi Yer"
    case nature = "Doğa"
    case lake = "Göl"
    case ski = "Kayak Merkezi"
    case thermal = "Termal"
    case viewpoint = "Manzara Noktası"
    case nightlife = "Gece Hayatı"

    var systemImage: String {
        switch self {
        case .beach: return "beach.umbrella.fill"
        case .cove: return "water.waves"
        case .island: return "mappin.and.ellipse"
        case .village: return "house.fill"
        case .town: return "building.2.fill"
        case .historic: return "building.columns.fill"
        case .nature: return "leaf.fill"
        case .lake: return "drop.fill"
        case .ski: return "snowflake"
        case .thermal: return "thermometer.sun.fill"
        case .viewpoint: return "mountain.2.fill"
        case .nightlife: return "sparkles"
        }
    }
}

/// Kullanıcının bu tatilde uğramayı planladığı nokta — arama kataloğundan
/// (bkz. `WaypointCatalog`) seçilir, tatil/güzergah eşleşmesi için kullanılır.
struct RouteWaypoint: Identifiable, Hashable, Codable {
    var id: String { name + district }   // katalogda sabit, tekrar seçimde çakışmayı önler
    var name: String
    var district: String      // ilçe
    var province: String      // il
    var category: WaypointCategory
    var popularity: Int       // arama sıralaması için (yüksek = daha popüler)
}

/// Bir seyahatte (uçuş/otel) o an eşleşme havuzunda görünen kişi kartı
struct TripFellowTraveler: Identifiable, Hashable {
    let id: String
    var user: AppUser
    var sharedTrip: Trip
    var matchStatus: MatchStatus

    static func == (lhs: TripFellowTraveler, rhs: TripFellowTraveler) -> Bool { lhs.id == rhs.id }
}

enum MatchStatus: String {
    case none
    case pendingSentByMe
    case pendingReceivedByMe
    case accepted
    case rejected
    case blocked   // taraflardan biri diğerini engelledi — UI'da hiç gösterilmez
}

enum ReportReason: String, CaseIterable, Identifiable {
    case inappropriateBehavior = "Uygunsuz davranış"
    case fakeProfile = "Sahte profil"
    case harassment = "Taciz"
    case spam = "Spam / reklam"
    case safetyConcern = "Güvenlik endişesi"
    case other = "Diğer"

    var id: String { rawValue }
    var systemImage: String {
        switch self {
        case .inappropriateBehavior: return "exclamationmark.bubble.fill"
        case .fakeProfile: return "person.crop.circle.badge.xmark"
        case .harassment: return "hand.raised.slash.fill"
        case .spam: return "megaphone.fill"
        case .safetyConcern: return "shield.lefthalf.filled"
        case .other: return "ellipsis.circle.fill"
        }
    }
}
