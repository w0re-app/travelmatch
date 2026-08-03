# TravelMatch — Firebase Entegrasyonlu iOS Prototipi

> App Store'a Codemagic ile yayınlamak için **`DEPLOYMENT.md`**'ye bak — `codemagic.yaml`
> bu repoda hazır, adım adım kurulum talimatları orada.

## ⚠️ Şu anki geçici durum (Blaze plan aktif değil)

Firebase **Blaze** (kullandıkça öde) faturalandırma planı henüz aktif değil — bu yüzden
**Cloud Functions ve Storage kullanılamıyor** (ikisi de Spark/ücretsiz planda çalışmıyor).
Bunun yerine, aşağıdaki geçici düzenlemeler yapıldı:

| Ne | Normalde | Şu an (geçici) |
|---|---|---|
| Trip oluşturma, eşleşme, bildirme/engelleme | `functions/index.js` içindeki Cloud Functions | `TripService` / `MatchService` / `ModerationService` doğrudan Firestore'a yazıyor |
| Uçuş gerçeklik kontrolü (AviationStack) | Cloud Function içinde, API anahtarı gizli | **Devre dışı** — API anahtarı client'ta güvenle tutulamıyor |
| Sohbette fotoğraf gönderme | Firebase Storage | **Devre dışı** (`FeatureFlags.photoMessagingEnabled = false`) — buton görünüyor ama "yakında" uyarısı veriyor |
| Yeni eşleşme isteğinde push bildirimi | `notifyOnMatchRequest` Cloud Function tetikleyici | Çalışmıyor (sunucu tarafı gerekiyor) |
| Süresi dolan eşleşme/sohbetlerin otomatik silinmesi | `cleanupExpiredData` zamanlı Cloud Function | Çalışmıyor — şimdilik veriler manuel silinmeden kalıyor |

**`functions/index.js` ve orijinal `firestore.rules` dosyası silinmedi, değiştirilmedi.**
Blaze aktif olduğunda:

1. `firebase deploy --only functions` çalıştır (fonksiyonlar canlıya alınır)
2. `firestore.rules` dosyasının içeriğini `firestore.rules.cloudfunctions-backup` ile
   değiştir (daha sıkı, Cloud Functions'ın tekelinde olan orijinal kurallar), sonra
   `firebase deploy --only firestore:rules`
3. `TripService.swift`, `MatchService.swift`, `ModerationService.swift` dosyalarındaki
   ⚠️ yorumlu bölümleri, Cloud Function çağıran hallerine geri al (bu sohbetin geçmişinde
   duruyor) — ya da git commit geçmişinden ilgili sürümü geri getir
4. `FeatureFlags.photoMessagingEnabled = true` yap
5. Storage'ı Firebase Console'dan kur (**Databases and storage → Storage → Get started**)

### Şimdi (Blaze olmadan) yapman gereken tek zorunlu adım

Firestore'u "Production mode"da oluşturduğun için varsayılan kurallar **her şeyi
reddediyor** — uygulamanın çalışabilmesi için bu geçici `firestore.rules` dosyasının
deploy edilmesi **şart**, Blaze gerektirmez:

```bash
npm install -g firebase-tools
firebase login
firebase use --add          # travelMatch projesini seç
firebase deploy --only firestore:rules
```

## Mimari Özeti

- **Auth:** Firebase Auth + Sign in with Apple (App Store zorunluluğu)
- **Veritabanı:** Firestore (`users`, `trips`, `matches`, `matches/{id}/messages`)
- **Sunucu mantığı:** Cloud Functions (`functions/index.js`)
  - `verifyFlight` — AviationStack ile sefer numarasının gerçekliğini doğrular
  - `requestMatch` / `respondToMatch` — eşleşme akışını sunucu tarafında yönetir (client'ın
    doğrudan `matches` koleksiyonuna yazması `firestore.rules` ile kapatıldı)
  - `notifyOnMatchRequest` — yeni istekte push bildirimi
  - `cleanupExpiredData` — her gün çalışıp süresi dolmuş eşleşme/sohbetleri siler (gizlilik gereği)
- **Bildirim:** Firebase Cloud Messaging

**Önemli sınırlama:** Hiçbir üçüncü parti API, bir PNR'ı yolcu kimliğiyle doğrulayamaz
(bu, havayolunun kendi rezervasyon sistemine erişim ve ticari anlaşma gerektirir).
`verifyFlight` yalnızca "bu sefer numarası o tarihte gerçekten var mı" sorusunu yanıtlar.
Otel tarafında ise böyle bir doğrulama API'si pratikte hiç yok — otel bilgisi kullanıcı
beyanına dayalı kalır. Bu, `TripDTO.selfReported` alanıyla açıkça işaretleniyor.

## Kurulum Adımları

### 1) Firebase projesi

1. [Firebase Console](https://console.firebase.google.com) → yeni proje oluştur.
2. **Authentication → Sign-in method → Apple**'ı etkinleştir.
3. **Firestore Database**'i oluştur (production mode).
4. **Cloud Messaging**'i etkinleştir.
5. iOS uygulaması ekle (Bundle ID'ini Xcode projendekiyle aynı yap), `GoogleService-Info.plist`
   dosyasını indirip Xcode projesinin kök klasörüne sürükle ("Copy items if needed" işaretli).

### 2) Xcode — Firebase SDK ekleme (Swift Package Manager)

File → Add Package Dependencies → `https://github.com/firebase/firebase-ios-sdk` → şu ürünleri seç:
`FirebaseAuth`, `FirebaseFirestore`, `FirebaseFunctions`, `FirebaseMessaging`.

`TravelMatchApp.swift` içine Firebase'i başlatmayı ekle:

```swift
import FirebaseCore

@main
struct TravelMatchApp: App {
    init() { FirebaseApp.configure() }
    @StateObject private var appState = AppState()
    var body: some Scene {
        WindowGroup { RootView().environmentObject(appState) }
    }
}
```

Ayrıca **Signing & Capabilities → + Capability → Sign in with Apple** ve
**+ Capability → Push Notifications** eklemeyi unutma (App Store bunları zorunlu/gerekli tutuyor).

### 3) Push bildirimleri (APNs ↔ Firebase)

1. Apple Developer hesabından bir **APNs Auth Key (.p8)** oluştur (Certificates, Identifiers
   & Profiles → Keys).
2. Firebase Console → Project Settings → Cloud Messaging → Apple app configuration →
   bu `.p8` dosyasını, Key ID ve Team ID ile yükle.
3. Fiziksel cihazda test et — push bildirimleri simülatörde çalışmaz (iOS 16+ simülatör
   kısmi destekliyor ama güvenilir değil).
4. Uygulama ilk açıldığında iznin ne zaman isteneceği: şu an Keşfet ekranında bir banner
   olarak gösteriliyor (`NotificationPermissionBanner`), sistemin tek seferlik izin
   diyaloğunu boşa harcamamak için önce kullanıcıya "Aç" butonuyla soruluyor.

### 4) Cloud Functions dağıtımı

> ⚠️ **Bu adım Blaze plan gerektirir.** Blaze aktif değilse bu komutlar hata verir —
> şimdilik atla, "Şu anki geçici durum" bölümündeki client-direct-write moduyla devam et.
> Blaze aktif olunca buraya dön.

```bash
npm install -g firebase-tools
firebase login
cd functions && npm install
firebase functions:secrets:set AVIATIONSTACK_KEY   # aviationstack.com'dan ücretsiz key al
firebase deploy --only functions,firestore:rules
```

### 5) Firestore güvenlik kuralları

`firestore.rules` dosyası repoda hazır; yukarıdaki `deploy` komutu bunu da yükler.
Özet mantık: `matches` koleksiyonuna client asla doğrudan yazamaz (yalnızca Cloud
Functions/Admin SDK), mesajlar yalnızca eşleşme `accepted` durumundaysa yazılabilir.

## Klasör Yapısı

```
TravelMatch/TravelMatch/
  Models/         — UI katmanının kullandığı düz Swift modelleri
  Services/       — Firebase entegrasyon katmanı (Auth, Trip, Match, Chat)
  ViewModels/      — AppState: tek kaynak, servisleri UI'a bağlar
  Views/          — SwiftUI ekranları (önceki mesajda paylaşılan UI ile aynı)
functions/         — Node.js Cloud Functions
firestore.rules    — Firestore güvenlik kuralları
```

## Biniş Kartı / Rezervasyon Belgesiyle Doğrulama ("Soft Verification")

- Tarama tamamen **cihaz üzerinde** (Apple Vision framework) yapılır — fotoğrafın kendisi
  hiçbir sunucuya yüklenmez.
- **Uçuş:** biniş kartındaki PDF417 barkodu (IATA BCBP standardı) çözülür → yolcu adı, PNR,
  sefer no, tarih çıkarılır.
- **Otel:** barkod yoktur; rezervasyon belgesi/e-postası ekran görüntüsü üzerinde genel metin
  OCR'ı çalışır, otel adı ve onay kodu heuristik olarak tahmin edilir — kullanıcı bunu
  gönderme öncesi görüp düzeltebilir.
- **Mükerrer kullanım engeli:** Çıkarılan bilgiden (PNR+sefer+tarih ya da onay kodu+otel adı)
  geri döndürülemez bir SHA-256 hash üretilir ve yalnızca bu hash `submitTrip` Cloud
  Function'ına gönderilir. Fonksiyon, `documentClaims/{hash}` dokümanını bir **Firestore
  transaction** içinde kontrol eder: hash başka bir `uid` tarafından zaten kullanılmışsa
  `already-exists` hatasıyla reddedilir ve trip oluşturulmaz. Aynı kullanıcı aynı belgeyi
  tekrar gönderirse sorun olmaz (idempotent).
- **Barkod okunamazsa / kullanıcı fotoğraf yüklemek istemezse:** ekranda her zaman elle giriş
  alanları da açık kalır — fotoğraf sadece bu alanları önceden dolduran bir kısayoldur, zorunlu
  değildir.
- `trips` koleksiyonuna artık client doğrudan yazamıyor — tüm oluşturma mantığı (uçuş
  gerçeklik kontrolü + belge tekilliği + trip kaydı) tek bir `submitTrip` Cloud Function'ında
  toplandı, bu da tutarlılığı ve güvenliği artırıyor.

## Info.plist Gereksinimleri

Kamera kullanımı için (`CameraCaptureView`) şu anahtar zorunlu, yoksa uygulama App Store'da
reddedilir ve cihazda çöker:

```xml
<key>NSCameraUsageDescription</key>
<string>Biniş kartını veya rezervasyon belgeni taramak için kameraya ihtiyacımız var.</string>
```

Galeriden seçim `PhotosPicker` (PhotosUI, iOS 16+) ile yapılıyor — bu, gizliliği koruyan
sistem seçici olduğu için **ayrı bir izin/Info.plist anahtarı gerektirmez**.

## Görsel Tasarım — "Tatil Nightclub"

`DesignSystem/Theme.swift` tüm renk paletini, gradyanları ve tekrar kullanılabilir
stilleri (`.glassCard()`, `.neonGlow()`, `.buttonStyle(.neon)`, `.buttonStyle(.ghost)`,
`NightclubBackground`) tek yerde topluyor. Tema: koyu gece-mor zemin (`Theme.midnight` →
`Theme.plum`), neon mor/magenta/mercan gradyan CTA'lar (`Theme.primaryGradient`), turkuaz
ikincil vurgu (`Theme.accentGradient`) ve camsı (glassmorphism) kartlar. Yeni bir ekran
eklerken bu bileşenleri kullanmak tasarım dilini tutarlı tutar; renkleri doğrudan
`Color(...)` ile yazmak yerine her zaman `Theme.*` üzerinden çağır.

## Minimum iOS Sürümü

Proje `onChange`/`task` gibi modern SwiftUI API'lerini kullanıyor — **Deployment Target'ı
iOS 17** olarak ayarla (Xcode → proje ayarları → Deployment Info).

## Sohbet Özellikleri

- **Fotoğraf gönderme:** Kamera veya galeriden seçilen fotoğraf JPEG'e sıkıştırılıp
  (`~0.72` kalite) Firebase Storage'a `chatImages/{matchId}/{uuid}.jpg` yoluna yüklenir,
  ardından mesaj dokümanına `imageURL` yazılır. `storage.rules` bu klasöre yalnızca
  eşleşmenin iki tarafının erişebilmesini garanti eder (Firestore'daki `participants`
  alanına bakarak) ve dosya boyutunu 8 MB ile sınırlar.
- **Emoji gönderme:** Giriş çubuğundaki yüz ikonu bir emoji ızgarası açar (seyahat temalı
  kategoriler dahil); seçilen emoji taslak metne eklenir. Mesaj yalnızca 1-3 emoji
  karakterinden oluşuyorsa (`ChatService.isEmojiOnly`) otomatik olarak balonsuz, büyük
  punto ile gösterilir (iMessage tarzı).
- **Mesaj gruplama:** Aynı gönderenden 2 dakika içinde gelen art arda mesajlar tek grupta
  toplanır; yalnızca grubun son balonunda "kuyruk" köşesi ve altında saat damgası
  gösterilir — tekrarlı zaman bilgisi ve gereksiz görsel gürültü önlenir.
- **Başlıkta tıklanabilir profil:** Sohbet ekranının üst kısmındaki avatar+isim,
  `TravelerProfileSheet`'i açar — karşı tarafın avatarı, yaşı, biyografisi, ilgi alanı
  etiketleri, ortak seyahat bilgisi ve bir "Bildir/Engelle" aksiyonu (şu an sadece UI —
  gerçek bildirim akışı ileride eklenmeli) gösterir.
- **Tam ekran fotoğraf görüntüleyici:** Sohbetteki bir fotoğrafa dokunmak, yakınlaştırma
  (pinch-to-zoom) destekli tam ekran görünümü açar.

### Firebase Storage kurulumu

1. Firebase Console → Storage → "Get started" ile varsayılan bucket'ı oluştur.
2. `firebase deploy --only storage` ile `storage.rules` dosyasını yükle (yukarıdaki
   `firebase deploy` komutuna `storage:rules` hedefini de ekleyebilirsin).
3. Xcode'da SPM paket listesine **FirebaseStorage** ürününü de ekle (bkz. "Firebase SDK
   ekleme" adımı).
4. `cleanupExpiredData` fonksiyonu artık süresi dolmuş eşleşmelere ait sohbet
   fotoğraflarını da Storage'dan siliyor — ekstra bir işlem gerekmiyor.

## Bildirme / Engelleme

- Sohbet başlığındaki profile dokunup **"Bildir/Engelle"** ile açılan `ReportUserSheet`
  üzerinden: neden seçimi, isteğe bağlı detay, ve varsayılan olarak açık "ayrıca engelle"
  seçeneğiyle gönderilir.
- Sunucu tarafı (`reportUser`, `blockUser`, `unblockUser` Cloud Functions):
  - `reports/{id}` koleksiyonuna moderasyon kaydı düşer — client bunu asla okuyamaz/yazamaz.
  - Engelleme, `blocks/{blockerUid_blockedUid}` kaydı açar, engelleyenin `users/{uid}.blockedUids`
    dizisini (yalnızca Cloud Function yazabilir — Firestore kuralları client'ın bu alanı
    doğrudan değiştirmesini engelliyor) günceller ve **iki taraf arasında var olan eşleşmeyi
    anında `blocked` durumuna çeker** — bu, Firestore kuralları gereği mesaj gönderimini
    otomatik olarak durdurur (kurallar yalnızca `status == "accepted"` iken mesaja izin veriyor).
  - `requestMatch` fonksiyonu da her iki yöndeki `blocks` kaydını kontrol eder — engellenen/
    engelleyen biri tekrar eşleşme isteği gönderemez.
  - Keşfet listesi (`TripService.listenFellowTravelers`) hem kendi `blockedUids`'ini hem de
    karşı tarafın `blockedUids`'inde kendisinin olup olmadığını kontrol ederek engellenen
    kişileri otomatik gizler.
  - `blocked` durumundaki eşleşmeler `MatchesListView`'de hiç görünmez (AppState eşleşme
    akışında filtrelenir).

## Güzergah Ekleme (Uğranacak Noktalar)

- Doğrulama tamamlanınca (ya da Keşfet ekranındaki harita ikonundan istendiği zaman)
  `RouteBuilderView` açılır: arama kutusuna yazdıkça (`WaypointCatalog.search`) prefix
  eşleşen plaj/köy/kasaba/tarihi yer önerileri **popülerliğe göre azalan sırada** listelenir
  (örn. "ak" → Akyaka, Akbük...). Türkçe karakter/büyük-küçük harf duyarsız arama yapılır.
  Seçilen noktalar çip olarak üstte birikir, kaldırılabilir.
- Katalog şu an `Mock/WaypointCatalog.swift` içinde cihazda gömülü statik bir veri seti
  (Ege/Akdeniz sahil bölgeleri ağırlıklı, ~45 nokta) — anlık (typeahead) arama için
  Firestore'a gitmeye gerek bırakmıyor. Büyüdükçe bir Firestore koleksiyonuna/CMS'e
  taşınabilir; `WaypointCatalog.search` imzası aynı kalacak şekilde tasarlandı.
- Seçilen güzergah, `updateTripRoute` Cloud Function'ı ile trip dokümanına
  (`plannedWaypoints`) yazılır — yalnızca trip sahibi güncelleyebilir, en fazla 10 durak.
- **Ortak duraklar:** `TravelerProfileSheet`, senin güzergahınla karşı tarafın güzergahının
  kesişimini "Ortak Duraklar 🎉" bölümünde gösterir — aynı uçuşta/otelde olmasalar bile
  (örn. aynı ilçedeki farklı otellerde kalan iki kişi) ortak gidilecek yerler üzerinden de
  bağ kurulabiliyor.
- Keşfet ekranının üst bandında, o seyahat için kaydedilmiş güzergah küçük etiketler
  halinde gösterilir; harita ikonundan istediğin zaman düzenlenebilir.

## Güzergaha Göre Eşleşme Yüzdesi ve Otomatik Öneri

- `MatchScoring.routeMatchPercentage` iki kişinin güzergahları arasındaki **Jaccard
  benzerliğini** (kesişim / birleşim) yüzdeye çevirir — örn. sen 4, o 5 nokta seçti, 3'ü
  ortak → %50. İkisinden biri hiç güzergah seçmediyse yüzde gösterilmez (`nil`).
  Yüzde `MatchScoring.strongMatchThreshold` (varsayılan **%50**) ve üzerindeyse "güçlü
  eşleşme" sayılır.
- Her kişi kartında (`RouteMatchBar`) gradyanlı bir ilerleme çubuğu ve yüzde etiketi
  gösterilir; güçlü eşleşmelerde kartın kenarlığı parıldar ve köşesine
  `StrongMatchBadge` ("🔥 Güçlü Eşleşme") rozeti eklenir.
- **Otomatik öneri:** Keşfet listesi varsayılan olarak yüzdeye göre azalan sırada
  gösterilir — bu sıralamanın kendisi öneri mekanizmasıdır. Ayrıca eşiği geçen kişiler
  listenin en üstünde ayrı bir **"🔥 Senin İçin Önerilenler"** bölümünde toplanır, geri
  kalanlar "Diğerleri" başlığı altında devam eder. Aktif ilgi alanı filtresi bu
  sıralamadan önce uygulanır.

## Sırada Ne Var?

- Otel tarafı için gerçek API yerine e-posta domain kontrolü (örn. rezervasyon onay
  e-postasını Firebase Extensions ile parse etmek) değerlendirilebilir
- Bildirime dokununca ilgili sohbete derin bağlantı (deep link) ile gitme
- Profil fotoğrafı yükleme (Firebase Storage)
- Kart üzerinde belge ile doğrulanmış rozetini (şu an sadece VerificationView'da var)
  Keşfet listesindeki kişi kartlarına da taşımak
- "Engellenenler" listesini yönetebileceğin bir ayarlar ekranı (şu an `unblockUser`
  fonksiyonu hazır ama buna bağlı bir UI yok)
- `WaypointCatalog`'u büyüdükçe Firestore koleksiyonuna/bir CMS'e taşımak, böylece kod
  değişikliği gerektirmeden yeni bölge/nokta eklenebilsin
