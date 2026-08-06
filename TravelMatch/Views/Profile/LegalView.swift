import SwiftUI

/// Kullanım şartları ve gizlilik politikası. App Store, hesap oluşturan ve
/// kullanıcı içeriği barındıran uygulamalarda bu metinlerin uygulama içinden
/// erişilebilir olmasını istiyor.
///
/// NOT: Gizlilik politikasının ayrıca App Store Connect'e bir URL olarak da
/// girilmesi gerekiyor. Aynı metni bir web sayfasında yayınla (GitHub Pages
/// yeterli) ve o adresi oraya gir.
struct LegalView: View {
    enum Belge: String, Identifiable {
        case sartlar, gizlilik

        var id: String { rawValue }

        var baslik: String {
            switch self {
            case .sartlar:  return "Kullanım Şartları"
            case .gizlilik: return "Gizlilik Politikası"
            }
        }
    }

    let belge: Belge
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                NightclubBackground()
                ScrollView {
                    Text(metin)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                }
            }
            .navigationTitle(belge.baslik)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }

    private var metin: String {
        switch belge {
        case .sartlar:  return Self.kullanimSartlari
        case .gizlilik: return Self.gizlilikPolitikasi
        }
    }

    // MARK: - Metinler
    // Bunlar hukuki danışmanlık değildir; yayına çıkmadan önce bir avukata
    // okutman önerilir. Yine de App Store'un beklediği asgari içeriği kapsar.

    static let kullanimSartlari = """
    Son güncelleme: Ağustos 2026

    1. HİZMET
    TravelMatch, aynı uçuşta veya aynı konaklamada bulunan kullanıcıların \
    birbirini bulup iletişim kurmasını sağlayan bir uygulamadır. Uygulamayı \
    kullanarak bu şartları kabul etmiş olursun.

    2. YAŞ SINIRI
    Uygulamayı kullanabilmek için en az 18 yaşında olman gerekir.

    3. KABUL EDİLEBİLİR KULLANIM
    Şunları yapmamayı kabul edersin:
    - Taciz, tehdit, nefret söylemi veya ayrımcılık içeren davranışlar
    - Cinsel içerikli veya müstehcen mesaj ve görsel paylaşımı
    - Sahte kimlik kullanmak, başkasının kimliğine bürünmek
    - Reklam, spam veya ticari amaçlı toplu mesaj
    - Başkasına ait rezervasyon/biniş kartı bilgisi kullanmak
    - Yasa dışı herhangi bir faaliyet

    4. İÇERİK VE MODERASYON
    Paylaştığın içerikten sen sorumlusun. Uygulama içindeki "Bildir" ve \
    "Engelle" araçlarıyla uygunsuz davranışları bildirebilirsin. Bildirimler \
    24 saat içinde incelenir; kuralları ihlal eden içerik kaldırılır ve ilgili \
    hesap askıya alınabilir veya kapatılabilir.

    5. GÜVENLİK UYARISI
    Uygulama, tanımadığın kişilerle iletişim kurmanı sağlar. Kullanıcıların \
    kimliğini garanti etmeyiz. Buluşmalarda halka açık yerleri tercih et, \
    kişisel bilgilerini paylaşırken dikkatli ol.

    6. DOĞRULAMA ROZETİ
    Biniş kartı veya rezervasyon belgesi taratan kullanıcılarda doğrulama \
    rozeti görünür. Bu rozet, belgenin okunduğunu gösterir; kişinin kimliğinin \
    doğrulandığı anlamına gelmez.

    7. HESABIN
    Hesabını istediğin zaman uygulama içinden (Profil → Hesabı Sil) \
    silebilirsin. Silme işlemi geri alınamaz.

    8. SORUMLULUK SINIRI
    Uygulama "olduğu gibi" sunulur. Kullanıcılar arasındaki etkileşimlerden \
    doğan zararlardan sorumlu tutulamayız.

    9. DEĞİŞİKLİKLER
    Bu şartlar güncellenebilir. Önemli değişikliklerde uygulama içinde \
    bilgilendirilirsin.

    İletişim: umut.gurrkann@icloud.com
    """

    static let gizlilikPolitikasi = """
    Son güncelleme: Ağustos 2026

    1. TOPLADIĞIMIZ VERİLER

    Hesap bilgileri: Apple ile Giriş üzerinden gelen kullanıcı kimliği ve \
    (paylaşmayı seçersen) e-posta adresin.

    Profil bilgileri: Ad, yaş, kendini tanıtan metin, ilgi alanları, profil \
    fotoğrafı.

    Seyahat bilgileri: Uçuş kodu veya otel adı, tarihler, uğramayı planladığın \
    duraklar. Rezervasyon/PNR kodun ayrı ve korumalı bir alanda saklanır; \
    diğer kullanıcılar göremez.

    İletişim verileri: Eşleşmelerin ve sohbet mesajların, paylaştığın \
    fotoğraflar.

    Teknik veriler: Bildirim gönderebilmek için cihaz bildirim kimliği.

    2. NELERİ TOPLAMIYORUZ
    Konum bilgini toplamıyoruz. Biniş kartı ve rezervasyon belgesi \
    fotoğrafları cihazından hiç çıkmaz — tarama telefonunda yapılır, sunucuya \
    yalnızca geri döndürülemez bir doğrulama kodu gönderilir.

    3. VERİLERİ NASIL KULLANIYORUZ
    Aynı seyahati paylaşan kişileri eşleştirmek, mesajlaşmayı sağlamak, \
    kötüye kullanımı önlemek ve bildirimleri iletmek için.

    4. KİMLERLE PAYLAŞILIYOR
    Verilerini satmıyoruz. Altyapı sağlayıcıları olarak Google Firebase \
    (kimlik doğrulama, veritabanı, bildirim) ve Supabase (fotoğraf depolama) \
    kullanıyoruz. Yalnızca hizmetin çalışması için gereken veri işlenir.

    Diğer kullanıcılar şunları görebilir: adın, yaşın, tanıtım metnin, ilgi \
    alanların, profil fotoğrafın, seyahatinin yeri ve tarihleri. Rezervasyon \
    kodun görünmez.

    5. SAKLAMA SÜRESİ
    Verilerin, sen silene kadar veya hesabını kapatana kadar saklanır. \
    Seyahatlerini Ana Sayfa'dan tek tek silebilirsin.

    6. HAKLARIN
    Hesabını ve tüm verilerini uygulama içinden silebilirsin: Profil → Hesabı \
    Sil. Silme işlemi profilini, seyahatlerini, eşleşmelerini, mesajlarını ve \
    fotoğraflarını kapsar ve geri alınamaz.

    7. ÇOCUKLAR
    Uygulama 18 yaş altındaki kişilere yönelik değildir ve bilerek onlardan \
    veri toplamayız.

    8. İLETİŞİM
    Sorular ve veri talepleri için: umut.gurrkann@icloud.com
    """
}

#Preview {
    LegalView(belge: .gizlilik).preferredColorScheme(.dark)
}
