import Foundation
import CoreGraphics

struct MatchRecord: Identifiable, Hashable {
    let id: String
    var otherUser: AppUser
    var sharedTrip: Trip
    var status: MatchStatus
    var createdAt: Date
    var expiresAt: Date   // seyahat bitince otomatik arşivleme için
    var lastMessagePreview: String?
    var lastMessageDate: Date?

    static func == (lhs: MatchRecord, rhs: MatchRecord) -> Bool { lhs.id == rhs.id }
}

enum ChatMessageType: Hashable {
    case text
    case image
    case emoji   // tek/az sayıda emojiden oluşan mesaj — büyük, balonsuz gösterilir
}

struct ChatMessage: Identifiable, Hashable {
    let id: String
    var matchId: String
    var isFromMe: Bool
    var type: ChatMessageType = .text
    var content: String
    var imageURL: String? = nil
    var imageAspectRatio: CGFloat? = nil   // width / height, layout için
    var sentAt: Date
}
