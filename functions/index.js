const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const fetch = require("node-fetch");

admin.initializeApp();
const db = admin.firestore();

const AVIATIONSTACK_KEY = defineSecret("AVIATIONSTACK_KEY");

/**
 * verifyFlightWithProvider — yardımcı fonksiyon (dışa açılmıyor).
 * AviationStack ile sefer numarasının gerçekten var olup olmadığını kontrol
 * eder. Bu, yolcunun o uçakta olduğunu DEĞİL, seferin gerçek olduğunu
 * doğrular — PNR + yolcu kimliği eşleşmesi havayolu iş ortaklığı gerektirir.
 */
async function verifyFlightWithProvider(flightNumber, dateString, apiKey) {
  const url = `https://api.aviationstack.com/v1/flights?access_key=${apiKey}&flight_iata=${encodeURIComponent(flightNumber)}&flight_date=${encodeURIComponent(dateString)}`;
  const res = await fetch(url);
  if (!res.ok) return { verified: false };
  const json = await res.json();
  const flight = json?.data?.[0];
  return flight ? { verified: true } : { verified: false };
}

/**
 * submitTrip — Callable function (tek giriş noktası)
 *
 * Tüm trip oluşturma mantığı burada, sunucu tarafında toplanıyor:
 *  1) Uçuş ise gerçek sefer kontrolü (AviationStack)
 *  2) `documentHash` verilmişse (biniş kartı/rezervasyon fotoğrafından
 *     üretilmiş, geri döndürülemez kimlik) — Firestore transaction ile
 *     tekillik kontrolü: aynı belge daha önce BAŞKA bir hesap tarafından
 *     kullanılmışsa `already-exists` hatası döner ve trip OLUŞTURULMAZ.
 *     Aynı kullanıcı aynı belgeyi tekrar gönderirse (örn. yeniden deneme)
 *     buna izin verilir.
 *  3) trip dokümanı admin yetkisiyle yazılır (client trips'e doğrudan
 *     yazamaz — bkz. firestore.rules).
 */
exports.submitTrip = onCall({ secrets: [AVIATIONSTACK_KEY] }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Giriş yapmalısın.");
  const uid = request.auth.uid;

  const {
    type, referenceCode, locationIdentifier, startDate, endDate,
    verificationMethod, documentHash,
  } = request.data;

  if (!type || !locationIdentifier || !startDate || !endDate) {
    throw new HttpsError("invalid-argument", "Zorunlu alanlar eksik.");
  }
  if (type !== "flight" && type !== "hotel") {
    throw new HttpsError("invalid-argument", "Geçersiz seyahat türü.");
  }

  // 1) Belge tekillik kontrolü (varsa) — trip yazılmadan ÖNCE, transaction içinde.
  if (documentHash) {
    await db.runTransaction(async (tx) => {
      const claimRef = db.collection("documentClaims").doc(documentHash);
      const claimSnap = await tx.get(claimRef);

      if (claimSnap.exists && claimSnap.data().uid !== uid) {
        throw new HttpsError("already-exists", "Bu belge/biniş kartı daha önce başka bir hesap tarafından kullanılmış.");
      }
      if (!claimSnap.exists) {
        tx.set(claimRef, {
          uid,
          tripType: type,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // 2) Uçuş gerçeklik kontrolü (kimlik doğrulaması değil, sefer varlığı).
  let isVerified = false;
  let selfReported = true;

  if (type === "flight") {
    const dateOnly = String(startDate).slice(0, 10);
    const flightCheck = await verifyFlightWithProvider(locationIdentifier, dateOnly, AVIATIONSTACK_KEY.value());
    isVerified = flightCheck.verified;
    selfReported = false;
  }

  // Belgeyle doğrulama (barkod/OCR + tekillik kontrolünden geçti) ek güven sağlar.
  if (documentHash && verificationMethod === "document") {
    isVerified = true;
  }

  // 3) Trip dokümanını yaz.
  const tripRef = await db.collection("trips").add({
    ownerUid: uid,
    type,
    referenceCode: referenceCode || "",
    locationIdentifier,
    startDate: admin.firestore.Timestamp.fromDate(new Date(startDate)),
    endDate: admin.firestore.Timestamp.fromDate(new Date(endDate)),
    isVerified,
    selfReported,
    verificationMethod: verificationMethod || "manual",
    documentHash: documentHash || null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { tripId: tripRef.id, isVerified };
});

/**
 * performBlock — yardımcı fonksiyon (dışa açılmıyor).
 * blocks koleksiyonuna kayıt açar, engelleyenin blockedUids dizisini günceller
 * ve iki taraf arasında var olan eşleşmeyi "blocked" durumuna çekerek
 * mesajlaşmayı anında durdurur (Firestore kuralları yalnızca status=="accepted"
 * olan eşleşmelerde mesaj yazılmasına izin veriyor).
 */
async function performBlock(blockerUid, blockedUid) {
  const blockId = `${blockerUid}_${blockedUid}`;
  await db.collection("blocks").doc(blockId).set({
    blockerUid, blockedUid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await db.collection("users").doc(blockerUid).update({
    blockedUids: admin.firestore.FieldValue.arrayUnion(blockedUid),
  });

  const matches = await db.collection("matches").where("participants", "array-contains", blockerUid).get();
  const batch = db.batch();
  matches.docs.forEach((doc) => {
    if (doc.data().participants.includes(blockedUid)) {
      batch.update(doc.ref, { status: "blocked" });
    }
  });
  await batch.commit();
}

/**
 * reportUser — Callable function
 * Bir kullanıcıyı bildirir (moderasyon kaydı) ve isteğe bağlı olarak aynı anda
 * engeller (`alsoBlock`). Bildirim kaydı client'tan asla doğrudan okunamaz/
 * değiştirilemez (bkz. firestore.rules) — yalnızca bu fonksiyon yazar.
 */
exports.reportUser = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Giriş yapmalısın.");
  const reporterUid = request.auth.uid;
  const { reportedUid, matchId, reason, details, alsoBlock } = request.data;

  if (!reportedUid || !reason) throw new HttpsError("invalid-argument", "reportedUid ve reason zorunlu.");
  if (reportedUid === reporterUid) throw new HttpsError("invalid-argument", "Kendini bildiremezsin.");

  await db.collection("reports").add({
    reporterUid, reportedUid,
    matchId: matchId || null,
    reason,
    details: details || "",
    status: "pending",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  if (alsoBlock) {
    await performBlock(reporterUid, reportedUid);
  }

  return { success: true };
});

/**
 * blockUser / unblockUser — Callable functions
 * Bildirim olmadan yalnızca engelleme yapmak için (örn. profil ekranından).
 */
exports.blockUser = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Giriş yapmalısın.");
  const { blockedUid } = request.data;
  if (!blockedUid) throw new HttpsError("invalid-argument", "blockedUid zorunlu.");
  if (blockedUid === request.auth.uid) throw new HttpsError("invalid-argument", "Kendini engelleyemezsin.");

  await performBlock(request.auth.uid, blockedUid);
  return { success: true };
});

exports.unblockUser = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Giriş yapmalısın.");
  const uid = request.auth.uid;
  const { blockedUid } = request.data;
  if (!blockedUid) throw new HttpsError("invalid-argument", "blockedUid zorunlu.");

  await db.collection("blocks").doc(`${uid}_${blockedUid}`).delete();
  await db.collection("users").doc(uid).update({
    blockedUids: admin.firestore.FieldValue.arrayRemove(blockedUid),
  });
  return { success: true };
});

/**
 * updateTripRoute — Callable function
 * Kullanıcının bu seyahatte uğramayı planladığı noktaları (plaj/köy/kasaba vb.)
 * kaydeder. Yalnızca trip sahibi güncelleyebilir; trips client'tan doğrudan
 * yazılamadığı için bu da submitTrip gibi tek giriş noktası.
 */
exports.updateTripRoute = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Giriş yapmalısın.");
  const { tripId, waypoints } = request.data;
  if (!tripId || !Array.isArray(waypoints)) throw new HttpsError("invalid-argument", "tripId ve waypoints zorunlu.");
  if (waypoints.length > 10) throw new HttpsError("invalid-argument", "En fazla 10 durak seçebilirsin.");

  const tripRef = db.collection("trips").doc(tripId);
  const tripDoc = await tripRef.get();
  if (!tripDoc.exists) throw new HttpsError("not-found", "Seyahat bulunamadı.");
  if (tripDoc.data().ownerUid !== request.auth.uid) {
    throw new HttpsError("permission-denied", "Bu seyahat sana ait değil.");
  }

  await tripRef.update({ plannedWaypoints: waypoints });
  return { success: true };
});

/**
 * requestMatch — Callable function
 */
exports.requestMatch = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Giriş yapmalısın.");
  const fromUid = request.auth.uid;
  const { toUid, tripId } = request.data;
  if (!toUid || !tripId) throw new HttpsError("invalid-argument", "toUid ve tripId zorunlu.");
  if (toUid === fromUid) throw new HttpsError("invalid-argument", "Kendine istek gönderemezsin.");

  const tripDoc = await db.collection("trips").doc(tripId).get();
  if (!tripDoc.exists) throw new HttpsError("not-found", "Seyahat bulunamadı.");

  const [blockedByMe, blockedMe] = await Promise.all([
    db.collection("blocks").doc(`${fromUid}_${toUid}`).get(),
    db.collection("blocks").doc(`${toUid}_${fromUid}`).get(),
  ]);
  if (blockedByMe.exists || blockedMe.exists) {
    throw new HttpsError("permission-denied", "Bu kişiyle eşleşemezsin.");
  }

  const existing = await db.collection("matches")
    .where("participants", "array-contains", fromUid)
    .where("tripId", "==", tripId)
    .get();

  const duplicate = existing.docs.find(d => d.data().participants.includes(toUid));
  if (duplicate) throw new HttpsError("already-exists", "Bu kişiye zaten istek gönderdin.");

  const ref = await db.collection("matches").add({
    tripId,
    participants: [fromUid, toUid],
    initiatedBy: fromUid,
    status: "pending",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: tripDoc.data().endDate,
  });

  return { matchId: ref.id };
});

/**
 * respondToMatch — Callable function (accept/reject)
 */
exports.respondToMatch = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Giriş yapmalısın.");
  const { matchId, accept } = request.data;
  const uid = request.auth.uid;

  const ref = db.collection("matches").doc(matchId);
  const doc = await ref.get();
  if (!doc.exists) throw new HttpsError("not-found", "Eşleşme bulunamadı.");
  const data = doc.data();
  if (!data.participants.includes(uid)) throw new HttpsError("permission-denied", "Bu eşleşmeye erişimin yok.");
  if (data.initiatedBy === uid) throw new HttpsError("permission-denied", "Kendi isteğini onaylayamazsın.");

  await ref.update({ status: accept ? "accepted" : "rejected", respondedAt: admin.firestore.FieldValue.serverTimestamp() });
  return { status: accept ? "accepted" : "rejected" };
});

/**
 * Yeni eşleşme isteği oluşunca karşı tarafa push bildirimi gönder.
 */
exports.notifyOnMatchRequest = onDocumentCreated("matches/{matchId}", async (event) => {
  const data = event.data.data();
  const targetUid = data.participants.find((p) => p !== data.initiatedBy);
  const userDoc = await db.collection("users").doc(targetUid).get();
  const token = userDoc.data()?.fcmToken;
  if (!token) return;

  await admin.messaging().send({
    token,
    notification: {
      title: "Yeni eşleşme isteği",
      body: "Seyahatinde biri seninle bağlantı kurmak istiyor.",
    },
  });
});

/**
 * Her gün çalışır: süresi dolmuş (trip bitişinden 24 saat sonrası) eşleşme,
 * sohbet ve belge tekillik kayıtlarını arşivler/siler. Gizlilik gereksinimi:
 * veriler kalıcı tutulmaz.
 */
exports.cleanupExpiredData = onSchedule("every 24 hours", async () => {
  const cutoff = admin.firestore.Timestamp.fromMillis(Date.now() - 24 * 60 * 60 * 1000);

  const expiredMatches = await db.collection("matches").where("expiresAt", "<=", cutoff).get();
  const batch = db.batch();
  for (const doc of expiredMatches.docs) {
    const messages = await doc.ref.collection("messages").get();
    messages.forEach((m) => batch.delete(m.ref));
    batch.delete(doc.ref);

    // Bu eşleşmede paylaşılan sohbet fotoğraflarını Storage'dan da sil.
    try {
      await admin.storage().bucket().deleteFiles({ prefix: `chatImages/${doc.id}/` });
    } catch (e) {
      console.warn(`chatImages/${doc.id} silinemedi:`, e.message);
    }
  }
  await batch.commit();

  // Süresi dolmuş trip'lere bağlı belge tekillik kayıtlarını da temizle.
  const expiredTrips = await db.collection("trips").where("endDate", "<=", cutoff).get();
  const docBatch = db.batch();
  for (const trip of expiredTrips.docs) {
    const hash = trip.data().documentHash;
    if (hash) {
      docBatch.delete(db.collection("documentClaims").doc(hash));
    }
    docBatch.delete(trip.ref);
  }
  await docBatch.commit();
});
