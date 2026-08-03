import SwiftUI
import PhotosUI

struct TripEntryView: View {
    @EnvironmentObject var appState: AppState

    @State private var selectedType: TripType = .flight
    @State private var entryMode: EntryMode = .manual

    @State private var referenceCode: String = ""
    @State private var locationIdentifier: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date().addingTimeInterval(60 * 60 * 6)

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
                        TextField(selectedType == .flight ? "Sefer kodu (örn: TK2144)" : "Otel adı", text: $locationIdentifier)
                            .foregroundStyle(Theme.textPrimary)
                            .listRowBackground(Theme.glassFill)

                        TextField(selectedType == .flight ? "PNR kodu" : "Rezervasyon numarası", text: $referenceCode)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .foregroundStyle(Theme.textPrimary)
                            .listRowBackground(Theme.glassFill)

                        if selectedType == .flight {
                            DatePicker("Kalkış zamanı", selection: $startDate)
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
                        Text("Bilgilerin yalnızca aynı seyahati paylaştığın kişilerle eşleşmeni sağlamak için kullanılır ve seyahat bitiminde otomatik olarak silinir. Fotoğrafla doğrulamada görsel hiçbir yere yüklenmez — tarama cihazında yapılır, sunucuya yalnızca geri döndürülemez bir doğrulama kodu gönderilir.")
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
                Button {
                    submit()
                } label: {
                    Text("Doğrula ve Devam Et")
                }
                .buttonStyle(.neon)
                .padding()
            }
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

    private func submit() {
        let end = selectedType == .flight ? startDate.addingTimeInterval(60 * 60 * 3) : endDate
        appState.submitTrip(
            type: selectedType,
            referenceCode: referenceCode,
            locationIdentifier: locationIdentifier.isEmpty
                ? (selectedType == .flight ? "TK2144" : "Hilton Bosphorus Istanbul")
                : locationIdentifier,
            startDate: startDate,
            endDate: end,
            verificationMethod: verificationMethod,
            documentHash: documentHash
        )
    }
}

#Preview {
    TripEntryView().environmentObject(AppState()).preferredColorScheme(.dark)
}
