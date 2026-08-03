import Foundation

/// İki kişinin seçtiği güzergah (waypoint) listeleri arasındaki örtüşmeyi
/// yüzdeye çevirir — Jaccard benzerliği (kesişim / birleşim) kullanılır.
/// Örn: sen 4 nokta seçtin, o 5 nokta seçti, 3 tanesi ortak → 3/6 = %50.
enum MatchScoring {

    /// İkisi de en az bir durak seçmemişse `nil` döner (yüzde anlamsız/gösterilmez).
    static func routeMatchPercentage(mine: [RouteWaypoint], theirs: [RouteWaypoint]) -> Int? {
        guard !mine.isEmpty, !theirs.isEmpty else { return nil }
        let mineIds = Set(mine.map(\.id))
        let theirIds = Set(theirs.map(\.id))
        let union = mineIds.union(theirIds).count
        guard union > 0 else { return nil }
        let intersection = mineIds.intersection(theirIds).count
        return Int((Double(intersection) / Double(union) * 100).rounded())
    }

    /// Kartlarda/önerilerde "güçlü eşleşme" rozetini tetikleyen eşik.
    static let strongMatchThreshold = 50
}
