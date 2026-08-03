# TravelMatch — Mac'siz, Codemagic ile App Store'a Yayınlama

Bu rehber, elinde bir Mac **olmadan** ilerleyecek şekilde tasarlandı. `.xcodeproj`
dosyası elle Xcode'da değil, **XcodeGen** ile `project.yml`'den Codemagic'in bulut
Mac'inde otomatik üretiliyor — senin tek yapman gereken dosyaları GitHub'a push etmek.

Bu rehber sırayla izlenmeli; her adım bir sonrakinin ön koşulu.

## 0) Bu klasörü GitHub'a yükle

Bilgisayarında (Windows/Linux/her neyse, Mac gerekmiyor) [Git](https://git-scm.com/downloads)
kurulu olmalı. İndirdiğin `TravelMatch.zip`'i aç, terminalde (Windows'ta "Git Bash" veya
PowerShell) o klasöre gir:

```bash
cd TravelMatch      # zip'ten çıkan klasörün TAM İÇİNE gir — önemli, bir üst dizine değil
git init
git add .
git commit -m "Initial commit"
```

[GitHub](https://github.com)'da boş bir repo oluştur (README/gitignore eklemeden),
sonra:

```bash
git remote add origin https://github.com/KULLANICI_ADIN/travelmatch.git
git branch -M main
git push -u origin main
```

Repo kökünde `project.yml`, `codemagic.yaml`, `TravelMatch/` (kaynak kodlar),
`functions/`, `firestore.rules` gibi dosyaları görmelisin.

## 1) Apple Developer Portal — App ID ve capability'ler

1. [developer.apple.com/account](https://developer.apple.com/account) →
   Certificates, Identifiers & Profiles → Identifiers → **+**.
2. App IDs → App → Bundle ID: **`com.wore.travelmatch`** (bu, `project.yml`'de
   zaten tanımlı — değiştirmek istersen hem oradan hem buradan aynı anda değiştir).
3. Capabilities: **Sign In with Apple** ve **Push Notifications**'ı işaretle.
4. Kaydet.

## 2) App Store Connect — uygulama kaydı

1. [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → My Apps → **+** → New App.
2. Platform iOS, isim, birincil dil, bundle ID (`com.wore.travelmatch`), SKU
   (örn. `travelmatch-ios`) gir.
3. Mağaza bilgilerini (ekran görüntüsü vs.) şimdilik boş bırakabilirsin.

## 3) App Store Connect API Key (Codemagic için)

1. App Store Connect → Users and Access → **Integrations** → App Store Connect API.
2. **+** ile yeni key oluştur, **App Manager** erişim rolünü seç.
3. **Download API Key** — yalnızca bir kez indirilebilir, güvenli sakla.
4. Sayfa üstündeki **Issuer ID**'yi ve key'in **Key ID**'sini not al.

## 4) Codemagic — repoyu bağla

1. [codemagic.io](https://codemagic.io) → GitHub ile giriş yap, `travelmatch` reposunu ekle.
2. Codemagic kök dizindeki `codemagic.yaml`'ı otomatik bulmalı.
3. **Team settings → Integrations → Developer Portal** → App Store Connect API key'i
   ekle (adım 3'teki Issuer ID, Key ID, `.p8` içeriği), entegrasyona `travelmatch_api_key`
   adını ver (bu isim `codemagic.yaml`'daki `integrations.app_store_connect` ile
   birebir eşleşmeli).

## 5) Codemagic — environment variable grupları (App Store build'i için)

**Application → Environment variables**'da iki grup oluştur:

**Grup: `firebase_config`**
- Firebase Console'dan indirdiğin `GoogleService-Info.plist`'i bir metin editörüyle aç,
  tüm içeriğini kopyala, [base64encode.org](https://www.base64encode.org) gibi bir
  siteyle (ya da Windows'ta `certutil -encode`, Linux'ta `base64 -w0 dosya.plist`)
  base64'e çevir.
- Çıktıyı `GOOGLE_SERVICE_INFO_PLIST_BASE64` adıyla, **Secret** işaretli ekle.

**Grup: `app_signing`**
- `BUNDLE_ID` adıyla `com.wore.travelmatch` değerini gir (secret olması gerekmiyor).

## 6) İlk App Store build'ini tetikle

1. Codemagic'te uygulamanın sayfası → **Start new build** → `ios-app-store` workflow'u
   → `main` branch.
2. Build şu sırayla ilerler: Firebase plist'i yazma → **XcodeGen ile `.xcodeproj`
   üretme** → SPM paket çözümleme (Firebase SDK) → Apple'dan imzalama dosyalarını
   otomatik çekme → `.ipa` oluşturma → TestFlight'a yükleme.
3. Bitince App Store Connect → TestFlight sekmesinde build'i görürsün.

## 7) Firebase deploy (bu da Mac gerektirmez — Codemagic'te ikinci bir workflow)

Bu proje şu an Blaze plan aktif olmadığı için Cloud Functions kullanmıyor (bkz. ana
`README.md` → "Şu anki geçici durum"), ama **Firestore güvenlik kurallarının** deploy
edilmesi yine de gerekiyor — yoksa uygulama hiçbir şey okuyup yazamaz. Bunun için
`codemagic.yaml`'da ayrı, hafif bir `firebase-deploy` workflow'u var (Mac değil, Linux
kullanıyor, çok daha hızlı).

**Servis hesabı anahtarı oluştur** (bir kere yapılır):
1. [console.firebase.google.com](https://console.firebase.google.com) → travelMatch
   projesi → ⚙️ **Project settings** → **Service accounts** sekmesi.
2. **Generate new private key** → indirilen `.json` dosyasını sakla.
3. Terminalde bu dosyayı base64'e çevir: `base64 -w0 indirilen-dosya.json` (Windows'ta
   `certutil -encode indirilen-dosya.json cikti.txt`, sonra `cikti.txt`'nin içeriğini
   BEGIN/END satırları hariç kullan).

**Codemagic'te grup oluştur:**
- **Grup: `firebase_deploy_credentials`**
  - `FIREBASE_SERVICE_ACCOUNT_BASE64` → yukarıdaki base64 çıktısı, **Secret**
  - `FIREBASE_PROJECT_ID` → Firebase proje ID'n (Firebase Console → Project settings →
    "Project ID" alanı — proje adıyla aynı olmayabilir, örn. `travelmatch-8061c`)

**Build'i tetikle:**
Codemagic'te **Start new build** → `firebase-deploy` workflow'u → `main` branch. Bitince
Firebase Console → Firestore → **Rules** sekmesinde kuralların güncellendiğini görürsün.

> Bundan sonra `firestore.rules` dosyasında her değişiklik yapıp `main`'e push ettiğinde,
> bu workflow otomatik tetiklenip kuralları güncelleyecek (`triggering.events: push`).

## 8) Mağazaya gönderme (elle, ilk sürümde)

`codemagic.yaml`'da `submit_to_app_store: false` bilinçli kapalı — App Store Connect'te
ekran görüntüleri, açıklama, gizlilik beyanı gibi elle doldurulması gereken alanlar var:

1. App Store Connect → uygulaman → **App Store** sekmesi → bilgileri doldur.
2. **Build** alanından Codemagic'in yüklediği TestFlight build'ini seç.
3. **Submit for Review**.

## Notlar

- `agvtool new-version`, App Store Connect'teki en son build numarasını okuyup bir
  artırır — build numarası çakışması riskini ortadan kaldırır.
- CocoaPods kullanılmıyor, Swift Package Manager (Firebase SDK dahil) kullanılıyor —
  `project.yml`'deki `packages:` bölümü bunu tanımlıyor, XcodeGen projeye otomatik ekliyor.
- `project.yml`'i değiştirirsen (örn. yeni bir capability eklersen), bir sonraki
  Codemagic build'i bunu otomatik yakalar — elle hiçbir şey yapmana gerek yok, çünkü
  `.xcodeproj` her build'de sıfırdan üretiliyor.
- Gerçek bir uygulama simgesi (App Icon) henüz eklenmedi — App Store'a gönderim
  öncesinde `TravelMatch/Assets.xcassets/AppIcon.appiconset` içine 1024×1024 bir
  görsel eklemen gerekecek (bu paket boş bir iskelet içeriyor).
