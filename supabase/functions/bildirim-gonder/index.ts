// TravelMatch — bildirim gönderici (Supabase Edge Function)
//
// NEDEN VAR: Push göndermek servis hesabı anahtarı gerektirir, o da uygulamaya
// konulamaz. Cloud Functions kullanılamadığı için (Blaze planı yok) bu iş
// Supabase'e taşındı.
//
// AKIŞ: uygulama bir aksiyon aldıktan sonra (istek gönderdi / kabul etti /
// mesaj yazdı) bu fonksiyonu Firebase kimlik token'ıyla çağırır. Fonksiyon
// token'ı doğrular, çağıranın gerçekten o eşleşmenin tarafı olduğunu Firestore
// üzerinden kontrol eder, sonra karşı tarafa FCM bildirimi yollar.
//
// GEREKLİ GİZLİ DEĞİŞKENLER (Supabase > Edge Functions > Secrets):
//   FIREBASE_SERVICE_ACCOUNT  → servis hesabı JSON'unun tamamı
//   FIREBASE_PROJECT_ID       → örn. travelmatch-8061c
//   FIREBASE_WEB_API_KEY      → Firebase Console > Proje ayarları > Web API Key

const PROJE = Deno.env.get("FIREBASE_PROJECT_ID")!;
const WEB_API_KEY = Deno.env.get("FIREBASE_WEB_API_KEY")!;
const SERVIS_HESABI = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!);

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
};

// ---------------------------------------------------------------- yardımcılar

function b64url(veri: ArrayBuffer | string): string {
  const bytes = typeof veri === "string"
    ? new TextEncoder().encode(veri)
    : new Uint8Array(veri);
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToBinary(pem: string): ArrayBuffer {
  const gövde = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const ham = atob(gövde);
  const buf = new Uint8Array(ham.length);
  for (let i = 0; i < ham.length; i++) buf[i] = ham.charCodeAt(i);
  return buf.buffer;
}

/// Servis hesabıyla OAuth erişim token'ı alır (FCM + Firestore için).
let tokenÖnbellek: { token: string; sonGecerlilik: number } | null = null;

async function erisimTokeni(): Promise<string> {
  if (tokenÖnbellek && tokenÖnbellek.sonGecerlilik > Date.now() + 60_000) {
    return tokenÖnbellek.token;
  }

  const şimdi = Math.floor(Date.now() / 1000);
  const başlık = { alg: "RS256", typ: "JWT" };
  const iddia = {
    iss: SERVIS_HESABI.client_email,
    scope: [
      "https://www.googleapis.com/auth/firebase.messaging",
      "https://www.googleapis.com/auth/datastore",
    ].join(" "),
    aud: "https://oauth2.googleapis.com/token",
    iat: şimdi,
    exp: şimdi + 3600,
  };

  const imzalanacak = `${b64url(JSON.stringify(başlık))}.${b64url(JSON.stringify(iddia))}`;
  const anahtar = await crypto.subtle.importKey(
    "pkcs8",
    pemToBinary(SERVIS_HESABI.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const imza = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    anahtar,
    new TextEncoder().encode(imzalanacak),
  );

  const yanıt = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${imzalanacak}.${b64url(imza)}`,
    }),
  });

  if (!yanıt.ok) throw new Error(`OAuth token alınamadı: ${await yanıt.text()}`);
  const json = await yanıt.json();
  tokenÖnbellek = {
    token: json.access_token,
    sonGecerlilik: Date.now() + json.expires_in * 1000,
  };
  return json.access_token;
}

/// Çağıranın Firebase kimlik token'ını doğrular, UID döner.
async function cagiraniDogrula(idToken: string): Promise<string> {
  const yanıt = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${WEB_API_KEY}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ idToken }),
    },
  );
  if (!yanıt.ok) throw new Error("Kimlik doğrulanamadı.");
  const json = await yanıt.json();
  const uid = json.users?.[0]?.localId;
  if (!uid) throw new Error("Kimlik doğrulanamadı.");
  return uid;
}

const FS_TEMEL =
  `https://firestore.googleapis.com/v1/projects/${PROJE}/databases/(default)/documents`;

async function firestoreBelge(yol: string, token: string): Promise<any | null> {
  const yanıt = await fetch(`${FS_TEMEL}/${yol}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!yanıt.ok) return null;
  return (await yanıt.json()).fields ?? null;
}

// ------------------------------------------------------------------- bildirim

type Tur = "eslesmeIstegi" | "eslesmeKabul" | "yeniMesaj";

function icerik(tur: Tur, gonderenAd: string): { title: string; body: string } {
  switch (tur) {
    case "eslesmeIstegi":
      return { title: "Yeni eşleşme isteği", body: `${gonderenAd} seninle bağlantı kurmak istiyor.` };
    case "eslesmeKabul":
      return { title: "Eşleştiniz 🎉", body: `${gonderenAd} isteğini kabul etti. Sohbete başlayabilirsin.` };
    case "yeniMesaj":
      return { title: gonderenAd, body: "Yeni bir mesajın var." };
  }
}

Deno.serve(async (istek) => {
  if (istek.method === "OPTIONS") return new Response("ok", { headers: CORS });

  try {
    const idToken = istek.headers.get("Authorization")?.replace("Bearer ", "");
    if (!idToken) throw new Error("Yetkilendirme başlığı eksik.");

    const gonderenUid = await cagiraniDogrula(idToken);
    const { hedefUid, matchId, tur } = await istek.json() as {
      hedefUid: string; matchId: string; tur: Tur;
    };
    if (!hedefUid || !matchId || !tur) throw new Error("Eksik parametre.");
    if (hedefUid === gonderenUid) throw new Error("Kendine bildirim gönderilemez.");

    const token = await erisimTokeni();

    // Çağıran gerçekten bu eşleşmenin tarafı mı? Aksi halde herkes herkese
    // bildirim yollayabilirdi.
    const eslesme = await firestoreBelge(`matches/${matchId}`, token);
    const katilimcilar: string[] =
      eslesme?.participants?.arrayValue?.values?.map((v: any) => v.stringValue) ?? [];
    if (!katilimcilar.includes(gonderenUid) || !katilimcilar.includes(hedefUid)) {
      throw new Error("Bu eşleşmeye erişimin yok.");
    }

    const hedefGizli = await firestoreBelge(`userSecrets/${hedefUid}`, token);
    const fcmToken = hedefGizli?.fcmToken?.stringValue;
    if (!fcmToken) {
      // Karşı taraf bildirim izni vermemiş olabilir — hata değil.
      return new Response(JSON.stringify({ gonderildi: false, sebep: "token yok" }), {
        headers: { ...CORS, "Content-Type": "application/json" },
      });
    }

    const gonderen = await firestoreBelge(`users/${gonderenUid}`, token);
    const gonderenAd = gonderen?.fullName?.stringValue ?? "Bir yolcu";
    const { title, body } = icerik(tur, gonderenAd);

    const fcm = await fetch(
      `https://fcm.googleapis.com/v1/projects/${PROJE}/messages:send`,
      {
        method: "POST",
        headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
        body: JSON.stringify({
          message: {
            token: fcmToken,
            notification: { title, body },
            data: { matchId, tur },
            apns: { payload: { aps: { sound: "default", badge: 1 } } },
          },
        }),
      },
    );

    if (!fcm.ok) throw new Error(`FCM hatası: ${await fcm.text()}`);

    return new Response(JSON.stringify({ gonderildi: true }), {
      headers: { ...CORS, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ hata: String(e) }), {
      status: 400,
      headers: { ...CORS, "Content-Type": "application/json" },
    });
  }
});
