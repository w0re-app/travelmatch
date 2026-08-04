/**
 * Test verisi yükleyici — Firestore'a sahte kullanıcı ve seyahat yazar.
 *
 * Codemagic'teki "seed-mock-data" workflow'undan çalıştırılır; servis hesabı
 * anahtarıyla yönetici yetkisiyle yazar (client bunu yapamaz, firestore.rules
 * yalnızca kendi ownerUid'inle seyahat oluşturmana izin verir).
 *
 * Uçuş seyahatleri BUGÜNDEN İTİBAREN 14 GÜN boyunca her gün için ayrı ayrı
 * oluşturulur — böylece uygulamada PC1000'i hangi tarihle girersen gir
 * eşleşme çıkar. Otel konaklamaları da aynı 14 günlük pencereyi kapsar.
 */

const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

const GUN_SAYISI = 14;
const UCUS_KODU = "PC1000";
const OTEL_ANTALYA = "Lara Bay Resort & Spa";
const OTEL_MUGLA = "Azmak Kıyısı Butik Otel";

// IntentTag rawValue'larıyla birebir aynı olmalı (UserModel.swift)
const ETIKET = {
  kahve: "Kahve içelim",
  gezi: "Şehri birlikte gezelim",
  network: "İş networking'i",
  sohbet: "Sadece tanışmak/sohbet",
  yemek: "Birlikte yemek",
};

const KULLANICILAR = [
  { uid: "mock-elif",   fullName: "Elif Yıldız",   age: 27, bio: "Fotoğraf çekmeyi ve sahil kasabalarını severim.", intentTags: [ETIKET.kahve, ETIKET.gezi] },
  { uid: "mock-mert",   fullName: "Mert Kaya",     age: 31, bio: "Dalış sertifikam var, yazları denizde geçiririm.", intentTags: [ETIKET.yemek, ETIKET.sohbet] },
  { uid: "mock-zeynep", fullName: "Zeynep Arslan", age: 24, bio: "Antik kentleri gezmek için yola çıkarım.",         intentTags: [ETIKET.gezi, ETIKET.kahve] },
  { uid: "mock-can",    fullName: "Can Demir",     age: 35, bio: "Uzun yol bisikletçisiyim, sakin yerleri severim.", intentTags: [ETIKET.sohbet] },
  { uid: "mock-selin",  fullName: "Selin Öztürk",  age: 29, bio: "Kano ve sörf denemek için Akyaka'ya gidiyorum.",   intentTags: [ETIKET.kahve, ETIKET.yemek] },
  { uid: "mock-burak",  fullName: "Burak Şahin",   age: 26, bio: "Yeni insanlarla tanışmayı, yemek yemeyi severim.", intentTags: [ETIKET.yemek, ETIKET.network] },
];

// Kim nerede: uçuşta olanlar / otelde olanlar
const UCUSTAKILER = ["mock-elif", "mock-mert", "mock-zeynep", "mock-burak"];
const ANTALYA_OTELINDEKILER = ["mock-elif", "mock-mert", "mock-burak"];
const MUGLA_OTELINDEKILER = ["mock-can", "mock-selin"];

const ts = (d) => admin.firestore.Timestamp.fromDate(d);

function gunBasi(offsetGun) {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  d.setDate(d.getDate() + offsetGun);
  return d;
}

function tripDoc({ uid, type, locationIdentifier, startDate, endDate }) {
  return {
    ownerUid: uid,
    type,
    referenceCode: "",
    locationIdentifier,
    startDate: ts(startDate),
    endDate: ts(endDate),
    isVerified: false,          // kurallar client'ın true yazmasına izin vermiyor
    selfReported: true,
    verificationMethod: "manual",
    documentHash: null,
    plannedWaypoints: [],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    isMock: true,               // temizlik için işaret
  };
}

async function eskiMocklariSil() {
  const eskiTrips = await db.collection("trips").where("isMock", "==", true).get();
  let silinen = 0;
  while (silinen < eskiTrips.size) {
    const batch = db.batch();
    eskiTrips.docs.slice(silinen, silinen + 400).forEach((d) => batch.delete(d.ref));
    await batch.commit();
    silinen += 400;
  }
  console.log(`Eski mock seyahat silindi: ${eskiTrips.size}`);
}

async function kullanicilariYaz() {
  const batch = db.batch();
  for (const k of KULLANICILAR) {
    batch.set(db.collection("users").doc(k.uid), {
      fullName: k.fullName,
      age: k.age,
      bio: k.bio,
      intentTags: k.intentTags,
      isIncognito: false,
      fcmToken: null,
      blockedUids: [],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isMock: true,
    });
  }
  await batch.commit();
  console.log(`Kullanıcı yazıldı: ${KULLANICILAR.length}`);
}

async function seyahatleriYaz() {
  let sayac = 0;
  let batch = db.batch();

  // Uçuşlar: 14 gün boyunca her gün için ayrı trip
  for (let gun = 0; gun < GUN_SAYISI; gun++) {
    const tarih = gunBasi(gun);
    const bitis = new Date(tarih);
    bitis.setHours(23, 59, 0, 0);

    for (const uid of UCUSTAKILER) {
      const ref = db.collection("trips").doc();
      batch.set(ref, tripDoc({
        uid, type: "flight", locationIdentifier: UCUS_KODU,
        startDate: tarih, endDate: bitis,
      }));
      sayac++;
      if (sayac % 400 === 0) { await batch.commit(); batch = db.batch(); }
    }
  }

  // Oteller: tüm pencereyi kaplayan tek konaklama
  const pencereBaslangic = gunBasi(0);
  const pencereBitis = gunBasi(GUN_SAYISI);

  for (const [otel, uidler] of [[OTEL_ANTALYA, ANTALYA_OTELINDEKILER],
                                [OTEL_MUGLA, MUGLA_OTELINDEKILER]]) {
    for (const uid of uidler) {
      const ref = db.collection("trips").doc();
      batch.set(ref, tripDoc({
        uid, type: "hotel", locationIdentifier: otel,
        startDate: pencereBaslangic, endDate: pencereBitis,
      }));
      sayac++;
    }
  }

  await batch.commit();
  console.log(`Seyahat yazıldı: ${sayac}`);
}

(async () => {
  await eskiMocklariSil();
  await kullanicilariYaz();
  await seyahatleriYaz();
  console.log("");
  console.log("Uygulamada test etmek için:");
  console.log(`  Uçuş  → ${UCUS_KODU}, bugünden itibaren 14 gün içinde herhangi bir tarih`);
  console.log(`  Otel  → "${OTEL_ANTALYA}" ya da "${OTEL_MUGLA}"`);
  process.exit(0);
})().catch((e) => {
  console.error("Seed başarısız:", e);
  process.exit(1);
});
