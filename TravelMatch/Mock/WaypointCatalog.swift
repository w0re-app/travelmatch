import Foundation

/// Tatil noktası kataloğu — plaj, koy, ada, tarihi yer, doğa, göl, kayak ve
/// termal noktalarını kapsar. Veri `yerler.json` dosyasından okunur (81 il,
/// 580 kayıt); dosya bir sebeple okunamazsa küçük bir gömülü listeye düşer,
/// böylece güzergah ekranı hiçbir zaman boş kalmaz.
///
/// Firestore'a gitmeden anında (typeahead) arama yapabilmek için cihazda
/// tutuluyor.
enum WaypointCatalog {

    static let all: [RouteWaypoint] = yukle()

    private static func yukle() -> [RouteWaypoint] {
        guard let url = Bundle.main.url(forResource: "yerler", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let liste = try? JSONDecoder().decode([RouteWaypoint].self, from: data),
              !liste.isEmpty
        else {
            assertionFailure("yerler.json okunamadı — dosya hedefe eklenmiş mi?")
            return yedekListe
        }
        return liste
    }

    /// Baştan eşleşen (prefix), Türkçe karakter duyarsız arama; sonuçlar
    /// popülerliğe göre azalan sırada döner. Boş sorguda en popüler ilk N sonuç.
    static func search(_ query: String, limit: Int = 25) -> [RouteWaypoint] {
        let sorgu = normalize(query)
        let adaylar: [RouteWaypoint]
        if sorgu.isEmpty {
            adaylar = all
        } else {
            // Önce baştan eşleşenler, sonra içinde geçenler — "kaş" yazınca
            // Kaş üstte çıksın ama "Kaputaş" da kaybolmasın.
            let bastan = all.filter {
                normalize($0.name).hasPrefix(sorgu) || normalize($0.district).hasPrefix(sorgu)
            }
            let icinde = all.filter {
                !bastan.contains($0)
                    && (normalize($0.name).contains(sorgu)
                        || normalize($0.district).contains(sorgu)
                        || normalize($0.province).contains(sorgu))
            }
            adaylar = bastan.sorted { $0.popularity > $1.popularity }
                + icinde.sorted { $0.popularity > $1.popularity }
            return Array(adaylar.prefix(limit))
        }
        return adaylar.sorted { $0.popularity > $1.popularity }.prefix(limit).map { $0 }
    }

    /// Belirli bir kategorideki yerler — filtreleme için.
    static func kategoride(_ kategori: WaypointCategory, limit: Int = 50) -> [RouteWaypoint] {
        all.filter { $0.category == kategori }
            .sorted { $0.popularity > $1.popularity }
            .prefix(limit).map { $0 }
    }

    private static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive],
                     locale: Locale(identifier: "tr_TR"))
    }

    /// yerler.json okunamazsa kullanılan asgari liste.
    private static let yedekListe: [RouteWaypoint] = [
        RouteWaypoint(name: "Ölüdeniz", district: "Fethiye", province: "Muğla", category: .beach, popularity: 97),
        RouteWaypoint(name: "Kaputaş Plajı", district: "Kaş", province: "Antalya", category: .beach, popularity: 93),
        RouteWaypoint(name: "Alaçatı", district: "Çeşme", province: "İzmir", category: .town, popularity: 96),
        RouteWaypoint(name: "Akyaka", district: "Ula", province: "Muğla", category: .beach, popularity: 92),
        RouteWaypoint(name: "Efes Antik Kenti", district: "Selçuk", province: "İzmir", category: .historic, popularity: 92),
        RouteWaypoint(name: "Göreme Açık Hava Müzesi", district: "Göreme", province: "Nevşehir", category: .historic, popularity: 95),
        RouteWaypoint(name: "Kaleiçi", district: "Merkez", province: "Antalya", category: .historic, popularity: 94),
        RouteWaypoint(name: "Bodrum Kalesi", district: "Bodrum", province: "Muğla", category: .historic, popularity: 95),
    ]
}
