import Foundation
import Vision
import UIKit
import CryptoKit

/// Biniş kartındaki PDF417 barkodunu (IATA BCBP standardı) çözer ve
/// otel rezervasyonu gibi barkodsuz belgeler için metin OCR'ı yapar.
/// Tüm işlem cihaz üzerinde (Vision framework) çalışır — görsel hiçbir
/// yere yüklenmez, sadece elde edilen metin/hash sunucuya gönderilir.
enum BoardingPassScannerService {

    struct BoardingPassData {
        var passengerName: String?
        var pnr: String?
        var carrier: String?
        var flightNumber: String?
        var fromAirport: String?
        var toAirport: String?
        var flightDate: Date?
        var seat: String?
        var rawBarcode: String
    }

    enum ScanResult {
        case boardingPass(BoardingPassData)
        case textOnly([String])   // barkod yok/çözülemedi — ham OCR satırları (örn. otel belgesi)
        case notFound
    }

    // MARK: - Ana giriş noktası

    static func scan(_ image: UIImage) async -> ScanResult {
        if let barcodeString = await detectBarcode(in: image) {
            if let parsed = parseBCBP(barcodeString) {
                return .boardingPass(parsed)
            }
            // Barkod okundu ama BCBP formatına uymuyor olabilir; yine de ham veriyi ver.
            return .textOnly([barcodeString])
        }

        let lines = await recognizeText(in: image)
        return lines.isEmpty ? .notFound : .textOnly(lines)
    }

    // MARK: - Barkod tespiti (PDF417 — boarding pass standardı)

    private static func detectBarcode(in image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { return nil }
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.PDF417, .QR, .Aztec]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            return request.results?.first?.payloadStringValue
        } catch {
            return nil
        }
    }

    // MARK: - Genel metin OCR (otel belgesi vb. için)

    private static func recognizeText(in image: UIImage) async -> [String] {
        guard let cgImage = image.cgImage else { return [] }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["tr-TR", "en-US"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            let observations = request.results ?? []
            return observations.compactMap { $0.topCandidates(1).first?.string }
        } catch {
            return []
        }
    }

    // MARK: - IATA BCBP (Bar Coded Boarding Pass) ayrıştırma
    // Kaynak: IATA Resolution 792 — "M1" formatı, zorunlu alanlar.
    // NOT: Havayolları arasında küçük varyasyonlar olabilir; ayrıştırma
    // başarısız olursa kullanıcı bilgileri elle düzeltebilir/girebilir.

    private static func parseBCBP(_ raw: String) -> BoardingPassData? {
        guard raw.count >= 60, raw.hasPrefix("M") else { return nil }
        let chars = Array(raw)

        func substring(_ range: Range<Int>) -> String {
            guard range.upperBound <= chars.count else { return "" }
            return String(chars[range]).trimmingCharacters(in: .whitespaces)
        }

        let nameField = substring(2..<22)          // Yolcu adı (SOYAD/AD formatında)
        let pnr = substring(23..<30)                // Rezervasyon kodu (PNR)
        let fromAirport = substring(30..<33)
        let toAirport = substring(33..<36)
        let carrier = substring(36..<39)
        let flightNumberRaw = substring(39..<44)
        let julianDateRaw = substring(44..<47)
        let seat = substring(48..<52)

        let flightDate = julianDateRaw.isEmpty ? nil : dateFromJulian(julianDateRaw)
        let flightNumber = carrier.isEmpty ? nil : "\(carrier)\(flightNumberRaw)".replacingOccurrences(of: " ", with: "")

        guard !pnr.isEmpty || flightNumber != nil else { return nil }

        return BoardingPassData(
            passengerName: nameField.isEmpty ? nil : nameField,
            pnr: pnr.isEmpty ? nil : pnr,
            carrier: carrier.isEmpty ? nil : carrier,
            flightNumber: flightNumber,
            fromAirport: fromAirport.isEmpty ? nil : fromAirport,
            toAirport: toAirport.isEmpty ? nil : toAirport,
            flightDate: flightDate,
            seat: seat.isEmpty ? nil : seat,
            rawBarcode: raw
        )
    }

    /// BCBP tarihleri yıl içermez (Julian gün no, 001-366); en yakın gelecekteki
    /// karşılığını hesaplıyoruz (bilet genelde yakın tarihli olur).
    private static func dateFromJulian(_ dayOfYearString: String) -> Date? {
        guard let dayOfYear = Int(dayOfYearString), dayOfYear > 0 else { return nil }
        let calendar = Calendar(identifier: .gregorian)
        let currentYear = calendar.component(.year, from: Date())

        for yearCandidate in [currentYear, currentYear + 1] {
            var comps = DateComponents()
            comps.year = yearCandidate
            comps.day = dayOfYear
            if let jan1 = calendar.date(from: DateComponents(year: yearCandidate, month: 1, day: 1)),
               let candidate = calendar.date(byAdding: .day, value: dayOfYear - 1, to: jan1),
               candidate.addingTimeInterval(60 * 60 * 24 * 2) > Date() {
                return candidate
            }
        }
        return nil
    }

    // MARK: - Otel belgesi için basit alan tahmini (heuristik OCR)

    static func extractHotelInfo(from lines: [String]) -> (hotelName: String?, confirmationNumber: String?) {
        var confirmationNumber: String?
        var hotelName: String?

        let confirmationKeywords = ["confirmation", "rezervasyon no", "booking", "onay kodu", "reservation"]
        for (index, line) in lines.enumerated() {
            let lower = line.lowercased()
            if confirmationKeywords.contains(where: { lower.contains($0) }) {
                // Aynı satırda veya bir sonraki satırda alfanumerik kod ara.
                if let code = extractAlphanumericCode(from: line) {
                    confirmationNumber = code
                } else if index + 1 < lines.count, let code = extractAlphanumericCode(from: lines[index + 1]) {
                    confirmationNumber = code
                }
            }
            if hotelName == nil, lower.contains("hotel") || lower.contains("otel") || lower.contains("resort") {
                hotelName = line
            }
        }

        // Hiçbir şey bulunamadıysa en uzun/ilk anlamlı satırı otel adı olarak öner.
        if hotelName == nil {
            hotelName = lines.first(where: { $0.count > 4 })
        }

        return (hotelName, confirmationNumber)
    }

    private static func extractAlphanumericCode(from line: String) -> String? {
        let pattern = #"[A-Z0-9]{5,10}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(line.startIndex..., in: line)
        guard let match = regex.firstMatch(in: line.uppercased(), range: range),
              let swiftRange = Range(match.range, in: line.uppercased()) else { return nil }
        return String(line.uppercased()[swiftRange])
    }

    // MARK: - Tekillik doğrulaması için hash

    /// Aynı belgenin ikinci bir hesap tarafından kullanılamaması için sunucuya
    /// gönderilecek geri döndürülemez (one-way) kimlik. Ham barkod/kişisel veri
    /// hiçbir zaman sunucuya gönderilmez — yalnızca bu hash gider.
    static func documentHash(forFlightPNR pnr: String, flightNumber: String, dateString: String) -> String {
        sha256("flight|\(pnr.uppercased())|\(flightNumber.uppercased())|\(dateString)")
    }

    static func documentHash(forHotelConfirmation confirmation: String, hotelName: String) -> String {
        sha256("hotel|\(confirmation.uppercased())|\(hotelName.lowercased())")
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).compactMap { String(format: "%02x", $0) }.joined()
    }
}
