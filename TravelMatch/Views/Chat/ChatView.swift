import SwiftUI
import PhotosUI

struct ChatView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let match: MatchRecord

    @State private var draft: String = ""
    @State private var showProfileSheet = false
    @State private var showEmojiPicker = false
    @State private var showAttachmentOptions = false
    @State private var showCamera = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showGalleryPicker = false
    @State private var showPhotoUnavailableAlert = false
    @State private var fullScreenImagePath: String?

    var body: some View {
        ZStack {
            NightclubBackground()

            VStack(spacing: 0) {
                expiryBanner
                messageList
                inputBar
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                headerButton
            }
        }
        .onAppear {
            appState.startListeningMessages(for: match)
        }
        .sheet(isPresented: $showProfileSheet) {
            TravelerProfileSheet(match: match) {
                dismiss()
            }
        }
        .sheet(isPresented: $showEmojiPicker) {
            EmojiPickerView { emoji in
                draft += emoji
            }
        }
        .fullScreenCover(item: Binding(
            get: { fullScreenImagePath.map { IdentifiableString(value: $0) } },
            set: { fullScreenImagePath = $0?.value }
        )) { wrapped in
            FullScreenImageViewer(imagePath: wrapped.value)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureView { image in
                appState.sendImage(image, in: match)
            }
        }
        .onChange(of: photoPickerItem) { _, newItem in
            Task {
                guard let newItem, let data = try? await newItem.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                appState.sendImage(image, in: match)
                photoPickerItem = nil
            }
        }
        .photosPicker(isPresented: $showGalleryPicker, selection: $photoPickerItem, matching: .images)
        .confirmationDialog("Fotoğraf Ekle", isPresented: $showAttachmentOptions, titleVisibility: .visible) {
            Button("Kamera") { showCamera = true }
            Button("Galeri") { showGalleryPicker = true }
            Button("Vazgeç", role: .cancel) {}
        }
    }

    // MARK: - Header

    private var headerButton: some View {
        Button {
            showProfileSheet = true
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(Theme.accentGradient).frame(width: 32, height: 32)
                    Image(systemName: "person.fill").font(.system(size: 13)).foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(match.otherUser.fullName)
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.textPrimary)
                    Text(match.sharedTrip.locationIdentifier)
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Mesaj listesi

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    let grouped = groupedMessages()
                    ForEach(Array(grouped.enumerated()), id: \.offset) { _, group in
                        ForEach(Array(group.enumerated()), id: \.element.id) { index, message in
                            MessageRow(
                                message: message,
                                isFirstInGroup: index == 0,
                                isLastInGroup: index == group.count - 1,
                                onTapImage: { path in fullScreenImagePath = path }
                            )
                        }
                        if let last = group.last {
                            Text(timeString(last.sentAt))
                                .font(.caption2)
                                .foregroundStyle(Theme.textTertiary)
                                .frame(maxWidth: .infinity, alignment: last.isFromMe ? .trailing : .leading)
                                .padding(.horizontal, 4)
                                .padding(.bottom, 8)
                        }
                    }
                }
                .padding(16)
            }
            .onChange(of: appState.messages(for: match).count) {
                if let last = appState.messages(for: match).last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    /// Aynı gönderenden art arda gelen (2 dakikadan yakın) mesajları tek grupta toplar —
    /// bu, mesaj balonu köşelerinin "kuyruk" mantığını ve tekrarlı zaman damgalarını önler.
    private func groupedMessages() -> [[ChatMessage]] {
        let messages = appState.messages(for: match)
        var groups: [[ChatMessage]] = []
        for message in messages {
            if let lastGroup = groups.last, let lastMessage = lastGroup.last,
               lastMessage.isFromMe == message.isFromMe,
               message.sentAt.timeIntervalSince(lastMessage.sentAt) < 120 {
                groups[groups.count - 1].append(message)
            } else {
                groups.append([message])
            }
        }
        return groups
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    // MARK: - Üst bilgi bandı

    private var expiryBanner: some View {
        HStack {
            Image(systemName: "clock.arrow.circlepath")
            Text("Sohbetleriniz eşleşme silinene kadar saklanır. Eşleşmeyi kaldırdığında mesajlar da silinir.")
                .font(.caption2)
        }
        .foregroundStyle(Theme.textTertiary)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.glassFill)
    }

    // MARK: - Alt giriş çubuğu

    private var inputBar: some View {
        HStack(spacing: 8) {
            Button {
                if FeatureFlags.photoMessagingEnabled {
                    showAttachmentOptions = true
                } else {
                    showPhotoUnavailableAlert = true
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(FeatureFlags.photoMessagingEnabled ? Theme.textPrimary : Theme.textTertiary)
                    .frame(width: 36, height: 36)
                    .background(Theme.glassFill)
                    .clipShape(Circle())
            }
            .alert("Fotoğraf Gönderme Yakında", isPresented: $showPhotoUnavailableAlert) {
                Button("Tamam", role: .cancel) {}
            } message: {
                Text("Bu özellik şu an aktif değil, çok yakında eklenecek.")
            }

            HStack(spacing: 6) {
                TextField("", text: $draft, prompt: Text("Mesaj yaz…").foregroundStyle(Theme.textTertiary), axis: .vertical)
                    .foregroundStyle(Theme.textPrimary)

                Button {
                    showEmojiPicker = true
                } label: {
                    Image(systemName: "face.smiling")
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.glassFill)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.glassStroke, lineWidth: 1))

            Button {
                appState.sendMessage(draft, in: match)
                draft = ""
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Theme.primaryGradient)
                    .clipShape(Circle())
                    .neonGlow(Theme.magenta, radius: 10)
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
        }
        .padding(12)
        .background(Theme.midnight.opacity(0.4))
    }
}

private struct IdentifiableString: Identifiable {
    let value: String
    var id: String { value }
}

// MARK: - Mesaj satırı (metin / emoji / fotoğraf)

private struct MessageRow: View {
    let message: ChatMessage
    let isFirstInGroup: Bool
    let isLastInGroup: Bool
    let onTapImage: (String) -> Void

    var body: some View {
        HStack {
            if message.isFromMe { Spacer(minLength: 40) }

            content

            if !message.isFromMe { Spacer(minLength: 40) }
        }
        .padding(.top, isFirstInGroup ? 6 : 2)
    }

    @ViewBuilder
    private var content: some View {
        switch message.type {
        case .emoji:
            Text(message.content)
                .font(.system(size: 44))

        case .image:
            // message.imageURL artık kalıcı bir adres değil, Supabase Storage yolu.
            if let path = message.imageURL {
                Button {
                    onTapImage(path)
                } label: {
                    SupabaseImageView(path: path) { image in
                        image.resizable().scaledToFill()
                    } placeholder: { failed in
                        if failed {
                            Theme.glassFill
                                .overlay(Image(systemName: "photo").foregroundStyle(Theme.textTertiary))
                        } else {
                            Theme.glassFill.overlay(ProgressView().tint(.white))
                        }
                    }
                    .frame(width: 200, height: 200 / max(message.imageAspectRatio ?? 1, 0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Theme.glassStroke, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

        case .text:
            Text(message.content)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    message.isFromMe
                        ? AnyShapeStyle(Theme.primaryGradient)
                        : AnyShapeStyle(Theme.glassFill)
                )
                .overlay(
                    bubbleShape.strokeBorder(message.isFromMe ? Color.clear : Theme.glassStroke, lineWidth: 1)
                )
                .clipShape(bubbleShape)
                .neonGlow(message.isFromMe ? Theme.magenta.opacity(0.4) : .clear, radius: 8)
        }
    }

    /// Grup içindeki konuma göre köşe yuvarlaklığını ayarlayan "kuyruklu" balon şekli.
    private var bubbleShape: UnevenRoundedRectangle {
        let sharpCorner: CGFloat = 6
        let roundCorner: CGFloat = 18
        let isTailCorner = isLastInGroup

        if message.isFromMe {
            return UnevenRoundedRectangle(
                topLeadingRadius: roundCorner,
                bottomLeadingRadius: roundCorner,
                bottomTrailingRadius: isTailCorner ? sharpCorner : roundCorner,
                topTrailingRadius: roundCorner
            )
        } else {
            return UnevenRoundedRectangle(
                topLeadingRadius: roundCorner,
                bottomLeadingRadius: isTailCorner ? sharpCorner : roundCorner,
                bottomTrailingRadius: roundCorner,
                topTrailingRadius: roundCorner
            )
        }
    }
}

#Preview {
    let state = AppState()
    let match = MockData.sampleMatches()[0]
    return NavigationStack { ChatView(match: match) }
        .environmentObject(state)
        .preferredColorScheme(.dark)
}
