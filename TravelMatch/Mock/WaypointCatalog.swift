import Foundation

/// Uygulama içinde gömülü, aranabilir tatil noktası kataloğu — plaj, köy, kasaba,
/// tarihi yer ve manzara noktalarını kapsar. Firestore'a gitmeden anında (typeahead)
/// arama yapabilmek için cihazda tutulur; büyüdükçe bir CMS/Firestore koleksiyonuna
/// taşınabilir (bkz. README "Sırada Ne Var?").
enum WaypointCatalog {

    static let all: [RouteWaypoint] = [
        // Gökova Körfezi / Muğla
        RouteWaypoint(name: "Akyaka", district: "Ula", province: "Muğla", category: .town, popularity: 92),
        RouteWaypoint(name: "Akbük", district: "Milas", province: "Muğla", category: .village, popularity: 68),
        RouteWaypoint(name: "Ören", district: "Milas", province: "Muğla", category: .town, popularity: 74),
        RouteWaypoint(name: "Gökova", district: "Ula", province: "Muğla", category: .village, popularity: 70),
        RouteWaypoint(name: "Sedir Adası (Kleopatra Plajı)", district: "Marmaris", province: "Muğla", category: .beach, popularity: 88),
        RouteWaypoint(name: "Karaincir Plajı", district: "Milas", province: "Muğla", category: .beach, popularity: 65),

        // Bodrum
        RouteWaypoint(name: "Bodrum Kalesi", district: "Bodrum", province: "Muğla", category: .historic, popularity: 95),
        RouteWaypoint(name: "Gümbet", district: "Bodrum", province: "Muğla", category: .beach, popularity: 84),
        RouteWaypoint(name: "Bitez", district: "Bodrum", province: "Muğla", category: .beach, popularity: 80),
        RouteWaypoint(name: "Gündoğan", district: "Bodrum", province: "Muğla", category: .town, popularity: 71),
        RouteWaypoint(name: "Türkbükü", district: "Bodrum", province: "Muğla", category: .nightlife, popularity: 86),
        RouteWaypoint(name: "Yalıkavak", district: "Bodrum", province: "Muğla", category: .nightlife, popularity: 89),
        RouteWaypoint(name: "Gümüşlük", district: "Bodrum", province: "Muğla", category: .village, popularity: 90),

        // Marmaris / Datça
        RouteWaypoint(name: "İçmeler", district: "Marmaris", province: "Muğla", category: .beach, popularity: 79),
        RouteWaypoint(name: "Turunç", district: "Marmaris", province: "Muğla", category: .town, popularity: 73),
        RouteWaypoint(name: "Datça", district: "Datça", province: "Muğla", category: .town, popularity: 85),
        RouteWaypoint(name: "Knidos Antik Kenti", district: "Datça", province: "Muğla", category: .historic, popularity: 66),

        // Fethiye / Ölüdeniz / Kaş / Kalkan
        RouteWaypoint(name: "Ölüdeniz", district: "Fethiye", province: "Muğla", category: .beach, popularity: 97),
        RouteWaypoint(name: "Kayaköy", district: "Fethiye", province: "Muğla", category: .village, popularity: 75),
        RouteWaypoint(name: "Butterfly Vadisi", district: "Fethiye", province: "Muğla", category: .viewpoint, popularity: 78),
        RouteWaypoint(name: "Kaş", district: "Kaş", province: "Antalya", category: .town, popularity: 91),
        RouteWaypoint(name: "Kalkan", district: "Kaş", province: "Antalya", category: .town, popularity: 87),
        RouteWaypoint(name: "Kaputaş Plajı", district: "Kaş", province: "Antalya", category: .beach, popularity: 93),
        RouteWaypoint(name: "Patara Plajı", district: "Kaş", province: "Antalya", category: .beach, popularity: 82),

        // Antalya
        RouteWaypoint(name: "Kaleiçi", district: "Muratpaşa", province: "Antalya", category: .historic, popularity: 94),
        RouteWaypoint(name: "Konyaaltı Plajı", district: "Muratpaşa", province: "Antalya", category: .beach, popularity: 83),
        RouteWaypoint(name: "Lara Plajı", district: "Muratpaşa", province: "Antalya", category: .beach, popularity: 81),
        RouteWaypoint(name: "Side Antik Kenti", district: "Manavgat", province: "Antalya", category: .historic, popularity: 88),
        RouteWaypoint(name: "Alanya Kalesi", district: "Alanya", province: "Antalya", category: .historic, popularity: 85),
        RouteWaypoint(name: "Çıralı", district: "Kemer", province: "Antalya", category: .beach, popularity: 77),
        RouteWaypoint(name: "Olympos", district: "Kemer", province: "Antalya", category: .historic, popularity: 76),

        // Çeşme / İzmir
        RouteWaypoint(name: "Alaçatı", district: "Çeşme", province: "İzmir", category: .town, popularity: 96),
        RouteWaypoint(name: "Ilıca Plajı", district: "Çeşme", province: "İzmir", category: .beach, popularity: 80),
        RouteWaypoint(name: "Altınkum", district: "Çeşme", province: "İzmir", category: .beach, popularity: 72),
        RouteWaypoint(name: "Foça", district: "Foça", province: "İzmir", category: .town, popularity: 69),
        RouteWaypoint(name: "Şirince", district: "Selçuk", province: "İzmir", category: .village, popularity: 84),
        RouteWaypoint(name: "Efes Antik Kenti", district: "Selçuk", province: "İzmir", category: .historic, popularity: 92),

        // Ayvalık / Balıkesir / Çanakkale
        RouteWaypoint(name: "Ayvalık", district: "Ayvalık", province: "Balıkesir", category: .town, popularity: 87),
        RouteWaypoint(name: "Cunda Adası", district: "Ayvalık", province: "Balıkesir", category: .village, popularity: 79),
        RouteWaypoint(name: "Assos", district: "Ayvacık", province: "Çanakkale", category: .historic, popularity: 74),
        RouteWaypoint(name: "Bozcaada", district: "Bozcaada", province: "Çanakkale", category: .town, popularity: 90),

        // Kapadokya / İç Anadolu (kısa örnek)
        RouteWaypoint(name: "Göreme", district: "Nevşehir", province: "Nevşehir", category: .village, popularity: 95),
        RouteWaypoint(name: "Uçhisar Kalesi", district: "Nevşehir", province: "Nevşehir", category: .viewpoint, popularity: 82),
    ]

    /// Baştan eşleşen (prefix), Türkçe karakter duyarsız arama; sonuçlar
    /// popülerliğe göre azalan sırada döner. Boş sorguda en popüler ilk N sonucu verir.
    static func search(_ query: String, limit: Int = 15) -> [RouteWaypoint] {
        let normalizedQuery = normalize(query)
        let candidates: [RouteWaypoint]
        if normalizedQuery.isEmpty {
            candidates = all
        } else {
            candidates = all.filter { normalize($0.name).hasPrefix(normalizedQuery) || normalize($0.district).hasPrefix(normalizedQuery) }
        }
        return candidates.sorted { $0.popularity > $1.popularity }.prefix(limit).map { $0 }
    }

    private static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "tr_TR"))
    }
}
