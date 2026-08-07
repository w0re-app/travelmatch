import SwiftUI

/// İl ve ardından ilçe seçtiren ekran. Liste `yerler.json`'daki 81 ilden
/// türetiliyor (bkz. SehirKatalogu), ayrı bir veri dosyası tutulmuyor.
struct SehirSeciciView: View {
    @Binding var secilenIl: String
    @Binding var secilenIlce: String
    var onBitti: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var acikIl: String?

    private var iller: [String] { SehirKatalogu.ilAra(query) }

    var body: some View {
        NavigationStack {
            ZStack {
                NightclubBackground()

                VStack(spacing: 0) {
                    aramaAlani

                    ScrollView {
                        LazyVStack(spacing: 8) {
                            if let acikIl {
                                ilceListesi(acikIl)
                            } else {
                                ForEach(iller, id: \.self) { il in
                                    Button {
                                        withAnimation { self.acikIl = il }
                                    } label: {
                                        satir(baslik: il, ikon: "mappin.circle.fill",
                                              altBaslik: "\(SehirKatalogu.ilceler(il).count) ilçe")
                                    }
                                    .buttonStyle(.plain)
                                }

                                if iller.isEmpty {
                                    Text("\"\(query)\" ile eşleşen il bulunamadı.")
                                        .font(.subheadline)
                                        .foregroundStyle(Theme.textTertiary)
                                        .padding(.top, 24)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle(acikIl ?? "Şehir Seç")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if acikIl != nil {
                        Button("Geri") { withAnimation { acikIl = nil } }
                    } else {
                        Button("Kapat") { dismiss() }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func ilceListesi(_ il: String) -> some View {
        // İlçe seçmek zorunlu değil — yalnızca ili seçip geçebilir.
        Button {
            sec(il: il, ilce: "")
        } label: {
            satir(baslik: "Tüm \(il)", ikon: "checkmark.circle.fill", altBaslik: "İlçe belirtmeden devam et")
        }
        .buttonStyle(.plain)

        ForEach(SehirKatalogu.ilceler(il), id: \.self) { ilce in
            Button {
                sec(il: il, ilce: ilce)
            } label: {
                satir(baslik: ilce, ikon: "building.2.fill", altBaslik: nil)
            }
            .buttonStyle(.plain)
        }
    }

    private func sec(il: String, ilce: String) {
        secilenIl = il
        secilenIlce = ilce
        onBitti()
        dismiss()
    }

    private var aramaAlani: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.textTertiary)
            TextField("", text: $query,
                      prompt: Text("İl ara…").foregroundStyle(Theme.textTertiary))
                .foregroundStyle(Theme.textPrimary)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.glassFill)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Theme.glassStroke, lineWidth: 1))
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .opacity(acikIl == nil ? 1 : 0)
        .frame(height: acikIl == nil ? nil : 0)
    }

    private func satir(baslik: String, ikon: String, altBaslik: String?) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Theme.accentGradient).frame(width: 34, height: 34)
                Image(systemName: ikon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(baslik).font(.subheadline.bold()).foregroundStyle(Theme.textPrimary)
                if let altBaslik {
                    Text(altBaslik).font(.caption).foregroundStyle(Theme.textTertiary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(12)
        .glassCard(cornerRadius: 14)
    }
}

#Preview {
    SehirSeciciView(secilenIl: .constant(""), secilenIlce: .constant(""))
        .preferredColorScheme(.dark)
}
