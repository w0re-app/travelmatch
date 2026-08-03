import SwiftUI

struct ProfileEditView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var fullName: String
    @State private var age: Int
    @State private var bio: String
    @State private var selectedTags: Set<IntentTag>

    init(user: AppUser) {
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
                    .disabled(!isValid)
                    .fontWeight(.bold)
                }
            }
        }
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
