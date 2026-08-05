import SwiftUI

/// Kullanıcının profil fotoğrafını Supabase Storage'dan çeker.
/// Fotoğraf yoksa (ya da yüklenemezse) SF Symbol'lü degrade daireye düşer.
///
/// `surum` değiştiğinde görsel yeniden yüklenir — yeni fotoğraf yüklendikten
/// sonra ekranın tazelenmesi için AppState bu değeri değiştiriyor.
struct AvatarView: View {
    let uid: String
    var boyut: CGFloat = 64
    var surum: UUID = UUID()

    @State private var url: URL?
    @State private var yukleniyor = true

    var body: some View {
        ZStack {
            Circle().fill(Theme.primaryGradient)

            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        yerTutucu
                    }
                }
            } else {
                yerTutucu
            }
        }
        .frame(width: boyut, height: boyut)
        .clipShape(Circle())
        .task(id: "\(uid)-\(surum)") {
            await adresiGetir()
        }
    }

    private var yerTutucu: some View {
        Group {
            if yukleniyor {
                ProgressView().tint(.white)
            } else {
                Image(systemName: "person.fill")
                    .foregroundStyle(.white)
                    .font(.system(size: boyut * 0.42))
            }
        }
    }

    private func adresiGetir() async {
        guard !uid.isEmpty else { yukleniyor = false; return }
        yukleniyor = true
        url = nil
        // Fotoğraf hiç yüklenmemişse imzalı URL üretimi hata verir — bu normal,
        // sessizce yer tutucuya düşüyoruz.
        url = try? await SupabaseDepo.ortak.profilFotografiUrl(uid: uid)
        yukleniyor = false
    }
}
