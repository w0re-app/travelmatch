import SwiftUI

struct ReportUserSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let reportedUser: AppUser
    let matchId: String?
    var onCompleted: () -> Void = {}

    @State private var selectedReason: ReportReason = .inappropriateBehavior
    @State private var details: String = ""
    @State private var alsoBlock: Bool = true
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            ZStack {
                NightclubBackground()

                Form {
                    Section {
                        Text("\(reportedUser.fullName) kişisini bildiriyorsun.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            .listRowBackground(Color.clear)
                    }

                    Section {
                        ForEach(ReportReason.allCases) { reason in
                            Button {
                                selectedReason = reason
                            } label: {
                                HStack {
                                    Label(reason.rawValue, systemImage: reason.systemImage)
                                        .foregroundStyle(Theme.textPrimary)
                                    Spacer()
                                    if selectedReason == reason {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Theme.magenta)
                                    }
                                }
                            }
                            .listRowBackground(Theme.glassFill)
                        }
                    } header: {
                        Text("Neden bildiriyorsun?").foregroundStyle(Theme.textTertiary)
                    }

                    Section {
                        TextField("", text: $details, prompt: Text("İsteğe bağlı detay ekle…").foregroundStyle(Theme.textTertiary), axis: .vertical)
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(3...6)
                            .listRowBackground(Theme.glassFill)
                    } header: {
                        Text("Detay").foregroundStyle(Theme.textTertiary)
                    }

                    Section {
                        Toggle(isOn: $alsoBlock) {
                            Label("Bu kişiyi ayrıca engelle", systemImage: "hand.raised.fill")
                                .foregroundStyle(Theme.textPrimary)
                        }
                        .tint(Theme.magenta)
                        .listRowBackground(Theme.glassFill)
                    } footer: {
                        Text("Engellersen bu kişi artık seni bulamaz, mesajlaşamaz ve aktif sohbetiniz kapanır.")
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Bildir")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        submit()
                    } label: {
                        if isSubmitting {
                            ProgressView().tint(Theme.magenta)
                        } else {
                            Text("Gönder").fontWeight(.bold).foregroundStyle(Theme.rose)
                        }
                    }
                    .disabled(isSubmitting)
                }
            }
        }
    }

    private func submit() {
        isSubmitting = true
        appState.reportUser(reportedUser.id, matchId: matchId, reason: selectedReason, details: details, alsoBlock: alsoBlock)
        // Sunucu çağrısı arka planda devam eder; kullanıcıyı bekletmeden akışı kapatıyoruz.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isSubmitting = false
            dismiss()
            onCompleted()
        }
    }
}

#Preview {
    ReportUserSheet(reportedUser: .mockCurrentUser, matchId: nil)
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
