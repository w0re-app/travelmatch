/**
 * Test verisi temizleyici — App Store incelemesine göndermeden ÖNCE çalıştır.
 *
 * Sahte profillerin canlıda kalması "yanıltıcı içerik" sayılır ve red sebebidir.
 * Bu script `isMock: true` işaretli tüm kullanıcı ve seyahat kayıtlarını,
 * ayrıca onlara bağlı eşleşme/mesajları siler.
 *
 * Codemagic'teki "clean-mock-data" workflow'undan elle çalıştırılır.
 */

const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

async function topluSil(docs, etiket) {
  let silinen = 0;
  while (silinen < docs.length) {
    const batch = db.batch();
    docs.slice(silinen, silinen + 400).forEach((d) => batch.delete(d.ref));
    await batch.commit();
    silinen += Math.min(400, docs.length - silinen);
  }
  console.log(`${etiket}: ${docs.length} kayıt silindi`);
}

(async () => {
  // 1) Mock kullanıcılar
  const mockUsers = await db.collection("users").where("isMock", "==", true).get();
  const mockUids = mockUsers.docs.map((d) => d.id);
  console.log(`Mock kullanıcı bulundu: ${mockUids.length}`);

  // 2) Mock seyahatler
  const mockTrips = await db.collection("trips").where("isMock", "==", true).get();
  await topluSil(mockTrips.docs, "Seyahat");

  // 3) Mock kullanıcıların dahil olduğu eşleşmeler + mesajları
  //    (array-contains-any en fazla 10 değer alır, parça parça sorguluyoruz)
  let eslesmeSayisi = 0;
  for (let i = 0; i < mockUids.length; i += 10) {
    const dilim = mockUids.slice(i, i + 10);
    if (dilim.length === 0) continue;
    const eslesmeler = await db.collection("matches")
      .where("participants", "array-contains-any", dilim).get();

    for (const doc of eslesmeler.docs) {
      const mesajlar = await doc.ref.collection("messages").get();
      await topluSil(mesajlar.docs, `  ${doc.id} mesajları`);
      await doc.ref.delete();
      eslesmeSayisi++;
    }
  }
  console.log(`Eşleşme: ${eslesmeSayisi} kayıt silindi`);

  // 4) Kullanıcıların kendisi
  await topluSil(mockUsers.docs, "Kullanıcı");

  console.log("");
  console.log("Test verisi temizlendi. İncelemeye gönderebilirsin.");
  process.exit(0);
})().catch((e) => {
  console.error("Temizlik başarısız:", e);
  process.exit(1);
});
