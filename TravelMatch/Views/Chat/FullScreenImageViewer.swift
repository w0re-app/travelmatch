import SwiftUI

/// Supabase Storage'daki bir dosya yolunu imzalı URL'e çevirip gösterir.
/// Firestore'da kalıcı URL tutulmuyor (bucket private), bu yüzden adres
/// gösterim anında üretiliyor ve 1 saat geçerli oluyor.
struct SupabaseImageView<Content: View, Placeholder: View>: View {
    let path: String
    @ViewBuilder var content: (Image) -> Content
    @ViewBuilder var placeholder: (Bool) -> Placeholder   // Bool: hata mı?

    @State private var url: URL?
    @State private var failed = false

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): content(image)
                    case .failure:            placeholder(true)
                    default:                  placeholder(false)
                    }
                }
            } else {
                placeholder(failed)
            }
        }
        .task(id: path) {
            failed = false
            url = nil
            do {
                url = try await SupabaseDepo.ortak.sohbetFotografiUrl(yol: path)
            } catch {
                failed = true
            }
        }
    }
}

struct FullScreenImageViewer: View {
    @Environment(\.dismiss) private var dismiss
    let imagePath: String

    @State private var scale: CGFloat = 1

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            SupabaseImageView(path: imagePath) { image in
                image
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in scale = max(1, min(value, 4)) }
                            .onEnded { _ in withAnimation(.spring()) { scale = 1 } }
                    )
            } placeholder: { failed in
                if failed {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.5))
                } else {
                    ProgressView().tint(.white)
                }
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Theme.glassFill)
                            .clipShape(Circle())
                    }
                    .padding(16)
                }
                Spacer()
            }
        }
    }
}
