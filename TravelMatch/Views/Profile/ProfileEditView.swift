import SwiftUI
import PhotosUI

struct ProfileEditView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var fullName: String
    @State private var age: Int
    @State private var bio: String
    @State private var selectedTags: Set<IntentTag>

    @State private var photoItem: PhotosPickerItem?

    private let userId: String

    init(user: AppUser) {
        userId = user.id
        _fullName = State(initialValue: user.fullName)
        _age = State(initialValue: user.age)
        _bio = State(initialValue: user.bio)
        _selectedTags = State(initialValue: Set(user.intentTags))
    }

    private var isValid: Bool {
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty && age >= 18 && age <= 100
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NightclubBackground()

                Form {
                    Section {
                        photoRow
                    } header: {
                        Text("Profil Fotoğrafı").foregroundStyle(Theme.textTertiary)
                    }

                    Section {
                        TextField("Ad Soyad", text: $fullName)
                            .foregroundStyle(Theme.textPrimary)
                            .listRowBackground(Theme.glassFill)
                        Stepper("Yaş: \(age)", value: $age, in: 18...100)
                            .foregroundStyle(Theme.textPrimary)
                            .listRowBackground(Theme.glassFill)
                    } header: {
                        Text("Temel Bilgiler").foregroundStyle(Theme.textTertiary)
                    }

                    Section {
                        TextField("", text: $bio, prompt: Text("Kendinden kısaca bahset…").foregroundStyle(Theme.textTertiary), axis: .vertical)
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(3...6)
                            .listRowBackground(Theme.glassFill)
                    } header: {
                        Text("Hakkında").foregroundStyle(Theme.textTertiary)
                    }

                    Section {
                        ForEach(IntentTag.allCases) { tag in
                            Button {
                                toggle(tag)
                            } label: {
                                HStack {
                                    Label(tag.rawValue, systemImage: tag.systemImage)
                                        .foregroundStyle(Theme.textPrimary)
                                    Spacer()
                                    if selectedTags.contains(tag) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Theme.magenta)
                                    }
                                }
                            }
                            .listRowBackground(Theme.glassFill)
                        }
                    } header: {
                        Text("Seyahatte amacın ne?").foregroundStyle(Theme.textTertiary)
                    }

                    if age < 18 {
                        Section {
                            Text("Uygulamayı kullanmak için en az 18 yaşında olman gerekiyor.")
                                .font(.caption)
                                .foregroundStyle(Theme.rose)
                                .listRowBackground(Color.clear)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Profili Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        appState.updateProfile(
                            fullName: fullName.trimmingCharacters(in: .whitespaces),
                            age: age,
                            bio: bio,
                            intentTags: Array(selectedTags)
                        )
                        dismiss()
                    }
                    .disabled(!isValid || appState.avatarYukleniyor)
                    .fontWeight(.bold)
                }
            }
            .onChange(of: photoItem) { _, yeni in
                Task {
                    guard let yeni,
                          let data = try? await yeni.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else { return }
                    appState.uploadProfilePhoto(image)
                    photoItem = nil
                }
            }
        }
    }

    // MARK: - Fotoğraf satırı

    private var photoRow: some View {
        HStack(spacing: 16) {
            AvatarView(uid: userId, boyut: 72, surum: appState.avatarSurumu)
                .overlay {
                    if appState.avatarYukleniyor {
                        Circle().fill(.black.opacity(0.45))
                            .overlay(ProgressView().tint(.white))
                    }
                }

            VStack(alignment: .leading, spacing: 6) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Text("Fotoğraf Seç")
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.violet)
                }
                .disabled(appState.avatarYukleniyor)

                if let hata = appState.avatarHatasi {
                    Text(hata)
                        .font(.caption)
                        .foregroundStyle(Theme.rose)
                } else {
                    Text("Fotoğrafın yalnızca aynı seyahati paylaştığın kişilere görünür.")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .listRowBackground(Color.clear)
    }

    private func toggle(_ tag: IntentTag) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }
}

#Preview {
    ProfileEditView(user: .mockCurrentUser).environmentObject(AppState()).preferredColorScheme(.dark)
}
