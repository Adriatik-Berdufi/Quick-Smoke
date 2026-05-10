import SwiftUI

enum BreathPhase: String {
    case inhale = "Inspira"
    case hold = "Trattieni"
    case exhale = "Espira"

    var seconds: Int {
        switch self {
        case .inhale: return 4
        case .hold: return 4
        case .exhale: return 6
        }
    }

    var hint: String {
        switch self {
        case .inhale: return "Inspira lentamente dal naso"
        case .hold: return "Mantieni il respiro con calma"
        case .exhale: return "Espira piano dalla bocca"
        }
    }
}

struct EmergencyCravingView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var remaining = 60
    @State private var phase: BreathPhase = .inhale
    @State private var phaseRemaining = 4
    @State private var breatheScale: CGFloat = 0.55
    @State private var timer: Timer?
    @State private var motivationalMessage = MotivationalMessages.random()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    breathingCard
                    motivationCard
                    distractionCard

                    Button("Chiudi") { dismiss() }
                        .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Modalita emergenza")
            .interactiveDismissDisabled()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Chiudi") { dismiss() }
                }
            }
            .onAppear(perform: startEmergencyMode)
            .onDisappear { timer?.invalidate() }
        }
    }

    private var breathingCard: some View {
        VStack(spacing: 12) {
            Text("Respirazione guidata 60 sec")
                .font(.headline)

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.cyan.opacity(0.7), Color.blue.opacity(0.25)],
                            center: .center,
                            startRadius: 12,
                            endRadius: 120
                        )
                    )
                    .frame(width: 180, height: 180)
                    .scaleEffect(breatheScale)

                if remaining == 0 {
                    Button("Riparti") {
                        startEmergencyMode()
                    }
                    .font(.title2.bold())
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                } else {
                    VStack(spacing: 4) {
                        Text(phase.rawValue)
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        Text("\(phaseRemaining)s")
                            .font(.title3.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.96))
                    }
                    .transaction { t in
                        t.animation = nil
                    }
                }
            }
            .frame(height: 200)

            Text(phase.hint)
                .foregroundStyle(.secondary)
                .transaction { t in
                    t.animation = nil
                }

            Text("Tempo rimanente: \(remaining)s")
                .font(.headline.monospacedDigit())
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var motivationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(motivationalMessage)
                .font(.title3.weight(.semibold))
            Text("Ogni minuto senza fumare conta. Hai gia superato il momento peggiore.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var distractionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mini distrazione")
                .font(.headline)

            NavigationLink {
                GameSelectionView()
            } label: {
                Text("Apri mini distrazione")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private func startEmergencyMode() {
        timer?.invalidate()
        remaining = 60
        motivationalMessage = MotivationalMessages.random()
        phase = .exhale
        phaseRemaining = phase.seconds
        breatheScale = 0.55
        updateBreathAnimation()

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            if remaining > 0 {
                remaining -= 1
            } else {
                t.invalidate()
            }

            if phaseRemaining > 1 {
                phaseRemaining -= 1
            } else {
                switch phase {
                case .inhale: phase = .hold
                case .hold: phase = .exhale
                case .exhale: phase = .inhale
                }
                phaseRemaining = phase.seconds
                updateBreathAnimation()
            }
        }
    }

    private func updateBreathAnimation() {
        let target: CGFloat
        switch phase {
        case .inhale: target = 1.0
        case .hold: target = 1.0
        case .exhale: target = 0.55
        }
        withAnimation(.easeInOut(duration: Double(phase.seconds))) {
            breatheScale = target
        }
    }

}
