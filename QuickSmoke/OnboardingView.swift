import SwiftUI

struct OnboardingView: View {
    @ObservedObject var viewModel: ChallengeViewModel

    @State private var cigarettesPerDay = 20
    @State private var sleepHours = 8.0
    @State private var wakeTime = Date()
    @State private var sleepTime = Date()
    @State private var mode: ChallengeMode = .graduale
    @State private var motivation = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Questionario iniziale") {
                    Stepper("Sigarette al giorno: \(cigarettesPerDay)", value: $cigarettesPerDay, in: 1...60)
                    Stepper("Ore di sonno: \(sleepHours, specifier: "%.1f")", value: $sleepHours, in: 3...12, step: 0.5)
                    DatePicker("Ora sveglia", selection: $wakeTime, displayedComponents: .hourAndMinute)
                    DatePicker("Ora sonno", selection: $sleepTime, displayedComponents: .hourAndMinute)
                    Picker("Modalita", selection: $mode) {
                        ForEach(ChallengeMode.allCases) { m in
                            Text(m.title).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Motivazione") {
                    TextField("Perche vuoi smettere?", text: $motivation, axis: .vertical)
                }

                Section {
                    Button("Inizia la sfida") {
                        viewModel.completeOnboarding(
                            cigarettesPerDay: cigarettesPerDay,
                            sleepHours: sleepHours,
                            wakeTime: wakeTime,
                            sleepTime: sleepTime,
                            mode: mode,
                            motivation: motivation
                        )
                    }
                }
            }
            .navigationTitle("SmokeLess Challenge")
        }
    }
}
