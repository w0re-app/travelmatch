import SwiftUI

struct FullScreenImageViewer: View {
    @Environment(\.dismiss) private var dismiss
    let imageURL: String

    @State private var scale: CGFloat = 1

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            AsyncImage(url: URL(string: imageURL)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in scale = max(1, min(value, 4)) }
                                .onEnded { _ in withAnimation(.spring()) { scale = 1 } }
                        )
                case .failure:
                    Image(systemName: "photo.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.5))
                default:
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
