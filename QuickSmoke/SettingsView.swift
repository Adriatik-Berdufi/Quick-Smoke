import SwiftUI
import UniformTypeIdentifiers
import UIKit

private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct SettingsView: View {
    @ObservedObject var viewModel: ChallengeViewModel

    @State private var cigarettesPerDay = 20
    @State private var sleepHours = 8.0
    @State private var wakeTime = Date()
    @State private var sleepTime = Date()
    @State private var packPrice = 6.0
    @State private var cigarettesPerPack = 20
    @State private var mode: ChallengeMode = .graduale
    @State private var motivation = ""
    @State private var initialCigarettesPerDay = 20
    @State private var initialSleepHours = 8.0
    @State private var initialWakeTime = Date()
    @State private var initialSleepTime = Date()
    @State private var initialPackPrice = 6.0
    @State private var initialCigarettesPerPack = 20
    @State private var initialMode: ChallengeMode = .graduale
    @State private var initialMotivation = ""
    @FocusState private var isMotivationFocused: Bool
    @State private var shareItem: ShareItem?
    @State private var showingImporter = false
    @State private var messageText: String?
    @State private var showingMessage = false
    @State private var showSavedBadge = false
    @State private var showResetConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Dati personali") {
                    Stepper("Sigarette al giorno: \(cigarettesPerDay)", value: $cigarettesPerDay, in: 1...60)
                    DatePicker("Orario sveglia", selection: $wakeTime, displayedComponents: .hourAndMinute)
                    DatePicker("Orario sonno", selection: $sleepTime, displayedComponents: .hourAndMinute)
                    LabeledContent("Ore sonno calcolate") {
                        Text("\(sleepHours, specifier: "%.1f") h")
                            .fontWeight(.semibold)
                    }
                    Picker("Modalita", selection: $mode) {
                        ForEach(ChallengeMode.allCases) { m in
                            Text("\(m.title) • \(initialIntervalLabel(for: m))").tag(m)
                        }
                    }
                }

                Section("Costo") {
                    Stepper("Prezzo pacchetto: \(packPrice, specifier: "%.2f") €", value: $packPrice, in: 3...20, step: 0.5)
                    Stepper("Sigarette per pacchetto: \(cigarettesPerPack)", value: $cigarettesPerPack, in: 10...40)
                }

                Section("Motivazione") {
                    TextField("La tua motivazione", text: $motivation, axis: .vertical)
                        .focused($isMotivationFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            isMotivationFocused = false
                        }
                }

                Section {
                    Button("Reset sfida", role: .destructive) {
                        showResetConfirmation = true
                    }
                }

                Section("Backup dati") {
                    Button("Esporta backup (Condividi)") {
                        do {
                            let data = try viewModel.exportProfileData()
                            let url = try backupURLAndWrite(data: data)
                            shareItem = ShareItem(url: url)
                        } catch {
                            showMessage(error.localizedDescription)
                        }
                    }

                    Button("Importa backup") {
                        showingImporter = true
                    }
                }
            }
            .navigationTitle("Impostazioni")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if hasChanges {
                        Button("Salva") {
                            saveSettings()
                        }
                    } else if isMotivationFocused {
                        Button("Fine") {
                            isMotivationFocused = false
                        }
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fine") {
                        isMotivationFocused = false
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear(perform: fillFromProfile)
            .onChange(of: wakeTime) { _, _ in
                recalculateSleepHours()
            }
            .onChange(of: sleepTime) { _, _ in
                recalculateSleepHours()
            }
            .sheet(item: $shareItem) { item in
                ActivityView(items: [item.url])
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    do {
                        let importedData = try Data(contentsOf: url)
                        try viewModel.importProfileData(importedData)
                        fillFromProfile()
                        showMessage("Backup importato con successo.")
                    } catch {
                        showMessage("Errore import: \(error.localizedDescription)")
                    }
                case .failure(let error):
                    showMessage("Import annullato o fallito: \(error.localizedDescription)")
                }
            }
            .alert("Backup dati", isPresented: $showingMessage) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(messageText ?? "")
            }
            .alert("Conferma reset", isPresented: $showResetConfirmation) {
                Button("Annulla", role: .cancel) {}
                Button("Resetta tutto", role: .destructive) {
                    viewModel.resetChallenge()
                }
            } message: {
                Text("Questa azione cancella tutti i progressi e non può essere annullata.")
            }
            .overlay(alignment: .bottom) {
                if showSavedBadge {
                    Text("Modifiche salvate")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 12)
                        .transition(.opacity)
                }
            }
        }
    }

    private func fillFromProfile() {
        guard let p = viewModel.profile else { return }
        cigarettesPerDay = p.cigarettesPerDay
        sleepHours = p.sleepHours
        wakeTime = makeTime(hour: p.wakeHour, minute: p.wakeMinute)
        sleepTime = makeTime(hour: p.sleepHour, minute: p.sleepMinute)
        recalculateSleepHours()
        packPrice = p.packPrice
        cigarettesPerPack = p.cigarettesPerPack
        mode = p.mode
        motivation = p.motivation
        syncInitialValuesToCurrent()
    }

    private var hasChanges: Bool {
        cigarettesPerDay != initialCigarettesPerDay ||
        abs(sleepHours - initialSleepHours) > 0.0001 ||
        !Calendar.current.isDate(wakeTime, equalTo: initialWakeTime, toGranularity: .minute) ||
        !Calendar.current.isDate(sleepTime, equalTo: initialSleepTime, toGranularity: .minute) ||
        abs(packPrice - initialPackPrice) > 0.0001 ||
        cigarettesPerPack != initialCigarettesPerPack ||
        mode != initialMode ||
        motivation != initialMotivation
    }

    private func syncInitialValuesToCurrent() {
        initialCigarettesPerDay = cigarettesPerDay
        initialSleepHours = sleepHours
        initialWakeTime = wakeTime
        initialSleepTime = sleepTime
        initialPackPrice = packPrice
        initialCigarettesPerPack = cigarettesPerPack
        initialMode = mode
        initialMotivation = motivation
    }

    private func showMessage(_ text: String) {
        messageText = text
        showingMessage = true
    }

    private func saveSettings() {
        isMotivationFocused = false
        viewModel.updateSettings(
            cigarettesPerDay: cigarettesPerDay,
            sleepHours: sleepHours,
            wakeTime: wakeTime,
            sleepTime: sleepTime,
            packPrice: packPrice,
            cigarettesPerPack: cigarettesPerPack,
            mode: mode,
            motivation: motivation
        )
        syncInitialValuesToCurrent()
        showSavedBadge = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            showSavedBadge = false
        }
    }

    private func initialIntervalLabel(for mode: ChallengeMode) -> String {
        let firstStepRate: Double
        switch mode {
        case .graduale: firstStepRate = 0.15
        case .medio: firstStepRate = 0.25
        case .intenso: firstStepRate = 0.35
        }

        let targetCigarettes = max(1, Int(floor(Double(max(1, cigarettesPerDay)) * (1 - firstStepRate))))
        let awakeHours = max(1, 24 - sleepHours)
        let base = Int(((awakeHours * 60) / Double(targetCigarettes)).rounded())
        let step = 5
        var rounded = Int((Double(base) / Double(step)).rounded()) * step
        if rounded < 20 { rounded = 20 }

        let h = rounded / 60
        let m = rounded % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }

    private func recalculateSleepHours() {
        let cal = Calendar.current
        let wakeMinutes = (cal.component(.hour, from: wakeTime) * 60) + cal.component(.minute, from: wakeTime)
        let sleepMinutes = (cal.component(.hour, from: sleepTime) * 60) + cal.component(.minute, from: sleepTime)

        let sleepDurationMinutes: Int
        if wakeMinutes >= sleepMinutes {
            sleepDurationMinutes = wakeMinutes - sleepMinutes
        } else {
            sleepDurationMinutes = (24 * 60 - sleepMinutes) + wakeMinutes
        }

        let computedSleep = Double(sleepDurationMinutes) / 60.0
        sleepHours = (computedSleep * 2).rounded() / 2
    }

    private func backupURLAndWrite(data: Data) throws -> URL {
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "quicksmoke-backup-\(timestamp).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return url
    }

    private func makeTime(hour: Int, minute: Int) -> Date {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        c.hour = hour
        c.minute = minute
        c.second = 0
        return Calendar.current.date(from: c) ?? Date()
    }
}
