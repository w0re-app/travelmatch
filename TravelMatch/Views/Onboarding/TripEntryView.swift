import SwiftUI
import PhotosUI

struct TripEntryView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    var onCompleted: () -> Void = {}

    @State private var selectedType: TripType = .flight
    @State private var entryMode: EntryMode = .manual

    @State private var referenceCode: String = ""
    @State private var locationIdentifier: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date().addingTimeInterval(60 * 60 * 3)

    @State private var secilenIl: String = ""
    @State private var secilenIlce: String = ""
    @State private var showIlSecici = false
    @State private var otelOnerisiGoster = false

    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var isScanning = false
    @State private var scanMessage: String?
    @State private var documentHash: String?
    @State private var verificationMethod: TripVerificationMethod = .manual

    enum EntryMode: String, CaseIterable, Identifiable {
        case manual = "Elle Gir"
        case photo = "Fotoğrafla Doğrula"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NightclubBackground()

                Form {
                    Section {
                        Picker("Tür", selection: $selectedType) {
                            ForEach(TripType.allCases) { type in
                                Label(type.rawValue, systemImage: type.systemImage).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                    } header: {
                        Text("Seyahat türü").foregroundStyle(Theme.textTertiary)
                    }

                    Section {
                        Picker("Yöntem", selection: $entryMode) {
                            ForEach(EntryMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                    } footer: {
                        Text(selectedType == .flight
                             ? "Biniş kartın varsa fotoğrafla doğrulama daha hızlı ve güvenilir. Yoksa bilgileri elle girebilirsin."
                             : "Rezervasyon onay belgeni/e-postanı fotoğraflayarak da girebilirsin.")
                        .foregroundStyle(Theme.textTertiary)
                    }

                    if entryMode == .photo {
                        photoSection
                    }

                    Section {
                        if selectedType == .hotel {
                            sehirSatiri
                        }

                        TextField(selectedType == .flight ? "Sefer kodu (örn: TK2144)" : "Otel adı", text: $locationIdentifier)
                            .foregroundStyle(Theme.textPrimary)
                            .autocorrectionDisabled()
                            .listRowBackground(Theme.glassFill)
                            .onChange(of: locationIdentifier) { _, _ in
                                otelOnerisiGoster = selectedType == .hotel && !locationIdentifier.isEmpty
                            }

                        if selectedType == .hotel, otelOnerisiGoster, !eslesenOteller.isEmpty {
                            ForEach(eslesenOteller.prefix(6), id: \.self) { otel in
                                Button {
                                    locationIdentifier = otel
                                    otelOnerisiGoster = false
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "building.2.fill")
                                            .foregroundStyle(Theme.cyan)
                                        Text(otel).foregroundStyle(Theme.textPrimary)
                                        Spacer()
                                        Image(systemName: "arrow.up.left")
                                            .font(.caption)
                                            .foregroundStyle(Theme.textTertiary)
                                    }
                                }
                                .listRowBackground(Theme.glassFill)
                            }
                        }

                        TextField(selectedType == .flight ? "PNR kodu" : "Rezervasyon numarası", text: $referenceCode)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .foregroundStyle(Theme.textPrimary)
                            .listRowBackground(Theme.glassFill)

                        if selectedType == .flight {
                            DatePicker("Kalkış zamanı", selection: $startDate)
                                .foregroundStyle(Theme.textPrimary)
                                .listRowBackground(Theme.glassFill)
                            // Sabit 3 saat varsayımı uzun uçuşlarda eşleşme
                            // penceresini yanlış hesaplıyordu.
                            DatePicker("Varış zamanı", selection: $endDate)
                                .foregroundStyle(Theme.textPrimary)
                                .listRowBackground(Theme.glassFill)
                        } else {
                            DatePicker("Giriş tarihi", selection: $startDate, displayedComponents: .date)
                                .foregroundStyle(Theme.textPrimary)
                                .listRowBackground(Theme.glassFill)
                            DatePicker("Çıkış tarihi", selection: $endDate, displayedComponents: .date)
                                .foregroundStyle(Theme.textPrimary)
                                .listRowBackground(Theme.glassFill)
                        }
                    } header: {
                        Text(selectedType == .flight ? "Uçuş bilgileri" : "Otel bilgileri").foregroundStyle(Theme.textTertiary)
                    }

                    Section {
                        Text("Bilgilerin yalnızca aynı seyahati paylaştığın kişilerle eşleşmeni sağlamak için kullanılır. Rezervasyon kodun diğer kullanıcılara gösterilmez. Seyahatlerini Ana Sayfa'dan istediğin zaman silebilirsin. Fotoğrafla doğrulamada görsel hiçbir yere yüklenmez — tarama cihazında yapılır, sunucuya yalnızca geri döndürülemez bir doğrulama kodu gönderilir.")
                            .font(.footnote)
                            .foregroundStyle(Theme.textTertiary)
                            .listRowBackground(Color.clear)
                    }
                }
                .scrollContentBackground(.hidden)
                .safeAreaPadding(.bottom, 80)
            }
            .navigationTitle("Seyahatini Ekle")
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showIlSecici) {
                SehirSeciciView(secilenIl: $secilenIl, secilenIlce: $secilenIlce) {
                    showIlSecici = false
                    if !secilenIl.isEmpty { appState.otelOnerileriniGetir(il: secilenIl) }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraCaptureView { image in
                    Task { await handleScannedImage(image) }
                }
            }
            .onChange(of: photoPickerItem) { _, newItem in
                Task {
                    guard let newItem, let data = try? await newItem.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else { return }
                    await handleScannedImage(image)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    if case .failed(let mesaj) = appState.verificationState {
                        Text(mesaj)
                            .font(.caption)
                            .foregroundStyle(Theme.rose)
                            .multilineTextAlignment(.center)
                    }
                    Button {
                        submit()
                    } label: {
                        if case .verifying = appState.verificationState {
                            ProgressView().tint(.white)
                        } else {
                            Text("Kaydet ve Devam Et")
                        }
                    }
                    .buttonStyle(.neon)
                    .disabled(!formGecerli || isVerifying)
                    .opacity(formGecerli && !isVerifying ? 1 : 0.5)
                }
                .padding()
            }
            .onChange(of: appState.verificationState) { _, yeni in
                if case .verified = yeni {
                    onCompleted()
                    dismiss()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
            }
        }
    }

    // MARK: - Şehir seçimi

    private var sehirSatiri: some View {
        Button {
            showIlSecici = true
        } label: {
            HStack {
                Label("Şehir", systemImage: "mappin.and.ellipse")
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(secilenIl.isEmpty ? "Seç" : (secilenIlce.isEmpty ? secilenIl : "\(secilenIl) · \(secilenIlce)"))
                    .foregroundStyle(secilenIl.isEmpty ? Theme.textTertiary : Theme.textSecondary)
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .listRowBackground(Theme.glassFill)
    }

    /// Yazılan metne göre süzülmüş otel önerileri.
    private var eslesenOteller: [String] {
        let q = locationIdentifier.folding(options: [.diacriticInsensitive, .caseInsensitive],
                                           locale: Locale(identifier: "tr_TR"))
        guard q.count >= 2 else { return [] }
        return appState.otelOnerileri.filter {
            $0.folding(options: [.diacriticInsensitive, .caseInsensitive],
                       locale: Locale(identifier: "tr_TR")).contains(q)
                && $0 != locationIdentifier
        }
    }

    private var photoSection: some View {
        Section {
            HStack(spacing: 12) {
                Button {
                    showCamera = true
                } label: {
                    Label("Kamera", systemImage: "camera.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.ghost)

                PhotosPicker(selection: $photoPickerItem, matching: .images) {
                    Label("Galeri", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity)
                }
                .buttonStyle(.ghost)
            }
            .listRowBackground(Color.clear)

            if isScanning {
                HStack {
                    ProgressView().tint(Theme.magenta)
                    Text("Belge taranıyor…").foregroundStyle(Theme.textSecondary)
                }
                .listRowBackground(Color.clear)
            }

            if let scanMessage {
                Label(scanMessage, systemImage: verificationMethod == .document ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(verificationMethod == .document ? Theme.mint : Theme.amber)
                    .listRowBackground(Color.clear)
            }
        } header: {
            Text(selectedType == .flight ? "Biniş Kartı" : "Rezervasyon Belgesi").foregroundStyle(Theme.textTertiary)
        }
    }

    private func handleScannedImage(_ image: UIImage) async {
        isScanning = true
        scanMessage = nil
        defer { isScanning = false }

        let result = await BoardingPassScannerService.scan(image)

        switch result {
        case .boardingPass(let data):
            if let flightNumber = data.flightNumber { locationIdentifier = flightNumber }
            if let pnr = data.pnr { referenceCode = pnr }
            if let date = data.flightDate { startDate = date }

            if let pnr = data.pnr, let flightNumber = data.flightNumber {
                let dateKey = ISO8601DateFormatter().string(from: startDate).prefix(10)
                documentHash = BoardingPassScannerService.documentHash(forFlightPNR: pnr, flightNumber: flightNumber, dateString: String(dateKey))
                verificationMethod = .document
                scanMessage = "Biniş kartı okundu: \(flightNumber) — bilgileri kontrol edip devam edebilirsin."
            } else {
                verificationMethod = .manual
                scanMessage = "Barkod kısmen okundu, eksik alanları elle tamamla."
            }

        case .textOnly(let lines):
            if selectedType == .hotel {
                let info = BoardingPassScannerService.extractHotelInfo(from: lines)
                if let name = info.hotelName { locationIdentifier = name }
                if let confirmation = info.confirmationNumber { referenceCode = confirmation }

                if let confirmation = info.confirmationNumber, let name = info.hotelName {
                    documentHash = BoardingPassScannerService.documentHash(forHotelConfirmation: confirmation, hotelName: name)
                    verificationMethod = .document
                    scanMessage = "Belge okundu — bilgileri kontrol edip devam edebilirsin."
                } else {
                    verificationMethod = .manual
                    scanMessage = "Belgeden bazı bilgiler okunamadı, lütfen eksikleri elle tamamla."
                }
            } else {
                verificationMethod = .manual
                scanMessage = "Biniş kartı barkodu okunamadı, lütfen bilgileri elle gir."
            }

        case .notFound:
            verificationMethod = .manual
            scanMessage = "Görselden bilgi okunamadı, lütfen bilgileri elle gir."
        }
    }

    private var formGecerli: Bool {
        let yerVar = !locationIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let sehirVar = selectedType == .flight || !secilenIl.isEmpty
        return yerVar && sehirVar && endDate > startDate
    }

    private var isVerifying: Bool {
        if case .verifying = appState.verificationState { return true }
        return false
    }

    /// Boş alan eskiden sahte bir uçuş koduyla ("TK2144") dolduruluyordu; bu,
    /// kullanıcıyı hiç gitmediği bir uçuştaki yabancılarla eşleştiriyordu.
    private func submit() {
        guard formGecerli else { return }
        // Uçuş kodları büyük harfe ve boşluksuz normalleştiriliyor —
        // "tk 2144" ile "TK2144" aynı uçuş sayılsın.
        let yer = selectedType == .flight
            ? locationIdentifier.uppercased().replacingOccurrences(of: " ", with: "")
            : locationIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)

        appState.submitTrip(
            type: selectedType,
            referenceCode: referenceCode,
            locationIdentifier: yer,
            startDate: startDate,
            endDate: endDate,
            il: selectedType == .hotel ? secilenIl : nil,
            ilce: selectedType == .hotel ? secilenIlce : nil,
            verificationMethod: verificationMethod,
            documentHash: documentHash
        )
    }
}

#Preview {
    TripEntryView().environmentObject(AppState()).preferredColorScheme(.dark)
}
