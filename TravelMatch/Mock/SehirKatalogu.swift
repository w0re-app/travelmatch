import Foundation

/// İl ve ilçe listesi — `yerler.json` içindeki 81 ilin verisinden türetilir,
/// ayrı bir dosya tutmaya gerek yok.
enum SehirKatalogu {

    /// Alfabetik il listesi.
    static let iller: [String] = {
        let hepsi = Set(WaypointCatalog.all.map(\.province))
        return hepsi.sorted { $0.localizedCompare($1) == .orderedAscending }
    }()

    /// Bir ildeki ilçeler.
    static func ilceler(_ il: String) -> [String] {
        let hepsi = Set(WaypointCatalog.all.filter { $0.province == il }.map(\.district))
        return hepsi.sorted { $0.localizedCompare($1) == .orderedAscending }
    }

    /// Türkçe karakter duyarsız il araması.
    static func ilAra(_ sorgu: String) -> [String] {
        let q = normalize(sorgu)
        guard !q.isEmpty else { return iller }
        return iller.filter { normalize($0).hasPrefix(q) || normalize($0).contains(q) }
    }

    private static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive],
                     locale: Locale(identifier: "tr_TR"))
    }
}
