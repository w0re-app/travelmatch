import Foundation
import UIKit
import Supabase
import FirebaseAuth

/// Supabase Storage üzerinden fotoğraf yükleme/indirme.
/// Kimlik doğrulama Firebase'den geliyor: her istekte Firebase ID token'ı
/// Supabase'e iletiliyor, RLS politikaları o token'daki UID'ye bakıyor.
@Observable
final class SupabaseDepo {

    static let ortak = SupabaseDepo()

    // MARK: - Yapılandırma

    private enum Ayar {
        // Project Settings > Data API
        static let url = URL(string: "https://jrrekhuftisfbflsabub.supabase.co")!
        // Project Settings > API Keys > Publishable key
        // (secret key ASLA buraya yazılmaz)
        static let anahtar = "sb_publishable_sb_publishable_jeeaXmpmPwUcaIsdG3Pegg_doGsm_Vj"

        static let profilKovasi = "profil-fotograflari"
        static let sohbetKovasi = "sohbet-fotograflari"

        static let enBuyukKenar: CGFloat = 1600
        static let sikistirmaKalitesi: CGFloat = 0.7
        static let imzaliUrlSuresi = 60 * 60   // 1 saat
    }

    private let istemci: SupabaseClient

    private init() {
        istemci = SupabaseClient(
            supabaseURL: Ayar.url,
            supabaseKey: Ayar.anahtar,
            options: .init(
                auth: .init(
                    // Her istekte güncel Firebase token'ı alınır.
                    accessToken: {
                        try await Auth.auth().currentUser?.getIDToken()
                    }
                )
            )
        )
    }

    // MARK: - Hatalar

    enum DepoHatasi: LocalizedError {
        case girisYapilmamis
        case gorselIslenemedi

        var errorDescription: String? {
            switch self {
            case .girisYapilmamis:  return "Bu işlem için giriş yapman gerekiyor."
            case .gorselIslenemedi: return "Fotoğraf işlenemedi, başka bir görsel dene."
            }
        }
    }

    private var uid: String? { Auth.auth().currentUser?.uid }

    // MARK: - Profil fotoğrafı

    /// Profil fotoğrafını yükler, indirilebilir imzalı URL döner.
    @discardableResult
    func profilFotografiYukle(_ gorsel: UIImage) async throws -> URL {
        guard let uid else { throw DepoHatasi.girisYapilmamis }
        let veri = try sikistir(gorsel)
        let yol = "\(uid)/avatar.jpg"

        try await istemci.storage
            .from(Ayar.profilKovasi)
            .upload(yol, data: veri,
                    options: FileOptions(contentType: "image/jpeg", upsert: true))

        return try await profilFotografiUrl(uid: uid)
    }

    func profilFotografiUrl(uid: String) async throws -> URL {
        try await istemci.storage
            .from(Ayar.profilKovasi)
            .createSignedURL(path: "\(uid)/avatar.jpg", expiresIn: Ayar.imzaliUrlSuresi)
    }

    func profilFotografiSil() async throws {
        guard let uid else { throw DepoHatasi.girisYapilmamis }
        try await istemci.storage
            .from(Ayar.profilKovasi)
            .remove(paths: ["\(uid)/avatar.jpg"])
    }

    // MARK: - Sohbet üyeliği

    /// Kullanıcı bir sohbete katıldığında çağrılır.
    /// Supabase tarafındaki üyelik kaydı olmadan o sohbetin fotoğraflarına erişilemez.
    func sohbeteKatil(sohbetId: String) async throws {
        guard let uid else { throw DepoHatasi.girisYapilmamis }
        struct Uyelik: Encodable {
            let sohbet_id: String
            let firebase_uid: String
        }
        try await istemci
            .from("sohbet_uyeleri")
            .upsert(Uyelik(sohbet_id: sohbetId, firebase_uid: uid),
                    onConflict: "sohbet_id,firebase_uid")
            .execute()
    }

    // MARK: - Sohbet fotoğrafı

    /// Sohbete fotoğraf yükler. Dönen yol Firestore'daki mesaj kaydına yazılmalı.
    func sohbetFotografiYukle(_ gorsel: UIImage, sohbetId: String) async throws -> String {
        guard let uid else { throw DepoHatasi.girisYapilmamis }
        let veri = try sikistir(gorsel)
        let yol = "\(sohbetId)/\(uid)-\(UUID().uuidString).jpg"

        try await istemci.storage
            .from(Ayar.sohbetKovasi)
            .upload(yol, data: veri,
                    options: FileOptions(contentType: "image/jpeg", upsert: false))

        return yol
    }

    /// Mesajdaki yol için geçici indirme adresi üretir.
    func sohbetFotografiUrl(yol: String) async throws -> URL {
        try await istemci.storage
            .from(Ayar.sohbetKovasi)
            .createSignedURL(path: yol, expiresIn: Ayar.imzaliUrlSuresi)
    }

    func sohbetFotografiSil(yol: String) async throws {
        try await istemci.storage
            .from(Ayar.sohbetKovasi)
            .remove(paths: [yol])
    }

    // MARK: - Görsel işleme

    /// Uzun kenarı küçültüp JPEG'e çevirir. Bucket sınırlarına takılmamak için şart:
    /// ham telefon fotoğrafı 5-8 MB olabiliyor, bu genelde 200-400 KB'ye iniyor.
    private func sikistir(_ gorsel: UIImage) throws -> Data {
        let boyut = gorsel.size
        let olcek = min(1, Ayar.enBuyukKenar / max(boyut.width, boyut.height))

        let hedef = CGSize(width: boyut.width * olcek, height: boyut.height * olcek)
        let cizici = UIGraphicsImageRenderer(size: hedef)
        let kucuk = cizici.image { _ in
            gorsel.draw(in: CGRect(origin: .zero, size: hedef))
        }

        guard let veri = kucuk.jpegData(compressionQuality: Ayar.sikistirmaKalitesi) else {
            throw DepoHatasi.gorselIslenemedi
        }
        return veri
    }
}
