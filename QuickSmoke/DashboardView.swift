import SwiftUI

struct DashboardView: View {
    private enum SmokingAction {
        case onTime
        case early
    }

    private struct RecoveryMilestone: Identifiable {
        let id = UUID()
        let title: String
        let detail: String
        let after: TimeInterval
    }

    @ObservedObject var viewModel: ChallengeViewModel
    @State private var showEmergency = false
    @State private var dailyGoals: [DailyGoal] = []
    @State private var completedGoalIDs: Set<String> = []
    @State private var goalsStreak = 0
    @State private var goalsDaysCompleted = 0
    @State private var pendingSmokingAction: SmokingAction?
    @State private var lastProfileSnapshot: ChallengeProfile?
    @State private var showUndoBanner = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    heroCard {
                        Text("Prossima sigaretta tra")
                            .font(.headline)
                        Text(viewModel.formattedRemaining())
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text(viewModel.motivationalLine)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack {
                            Spacer()
                            if viewModel.timerFinished {
                                Button("Resisti") { viewModel.resist() }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.green)
                            }
                            Button("Fumo") { pendingSmokingAction = .onTime }
                                .buttonStyle(.borderedProminent)
                                .tint(.orange)
                                .disabled(!viewModel.timerFinished)
                        }
                    }

                    HStack(spacing: 10) {
                        Button("Fumo prima") { pendingSmokingAction = .early }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)

                        Button("Ho voglia di fumare") {
                            showEmergency = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .frame(maxWidth: .infinity)
                    }

                    card {
                        HStack {
                            Text("Obiettivi di oggi")
                                .font(.headline)
                            Spacer()
                            Text("\(completedGoalsCount)/\(dailyGoals.count)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        ProgressView(value: Double(completedGoalsCount), total: Double(max(1, dailyGoals.count)))
                            .tint(.green)

                        ForEach(dailyGoals) { goal in
                            Button {
                                toggleGoal(goal.id)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: completedGoalIDs.contains(goal.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(completedGoalIDs.contains(goal.id) ? .green : .secondary)
                                    Text(goal.text)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text(goal.difficulty.title)
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(difficultyColor(goal.difficulty).opacity(0.16), in: Capsule())
                                        .foregroundStyle(difficultyColor(goal.difficulty))
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        if isAllGoalsDone {
                            Text("Ottimo: obiettivi di oggi completati.")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.green)
                        }

                        HStack {
                            Text("Streak obiettivi: \(goalsStreak) giorni")
                            Spacer()
                            Text("Giorni completati: \(goalsDaysCompleted)")
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }

                    card {
                        let stats = viewModel.todayStats
                        statRow("Sigarette fumate oggi", "\(stats.smoked)")
                        statRow("Sigarette evitate oggi", "\(stats.resisted)")
                        statRow("Tempo senza fumare", formatTime(viewModel.smokeFreeDuration))
                        statRow("Soldi risparmiati", viewModel.moneySaved.formatted(.currency(code: "EUR")))
                        let recoveredMinutes = (viewModel.profile?.totalResisted ?? 0) * 11
                        statRow("Tempo vita recuperato", "~\(recoveredMinutes) min")
                    }

                    card {
                        Text("Recupero corpo")
                            .font(.headline)

                        let smokeFree = max(0, viewModel.smokeFreeDuration)
                        let milestones = recoveryMilestones
                        let nextMilestone = milestones.first(where: { smokeFree < $0.after }) ?? milestones.last
                        let previousAfter = milestones.last(where: { $0.after <= smokeFree })?.after ?? 0
                        let targetAfter = nextMilestone?.after ?? max(1, smokeFree)
                        let progress = min(1, max(0, (smokeFree - previousAfter) / max(1, targetAfter - previousAfter)))

                        ProgressView(value: progress)
                            .tint(.green)

                        if let nextMilestone {
                            let remaining = max(0, Int(nextMilestone.after - smokeFree))
                            Text("Prossimo step: \(nextMilestone.title) tra \(formatDurationShort(seconds: remaining))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        VStack(spacing: 10) {
                            ForEach(milestones) { milestone in
                                let reached = smokeFree >= milestone.after
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: reached ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(reached ? .green : .secondary)
                                        .padding(.top, 2)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(milestone.title)
                                            .font(.subheadline.weight(.semibold))
                                        Text(milestone.detail)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }

                    card {
                        statRow("Giorno sfida", "\(viewModel.challengeDay)")
                        statRow("Livello", viewModel.levelTitle)
                        statRow("Intervallo attuale", viewModel.intervalLabel())
                        statRow("Prossimo aumento", "Tra \(viewModel.nextStepInDays) giorni")
                        Text("Tra \(viewModel.nextStepInDays) giorni passerai a un intervallo piu alto.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .fullScreenCover(isPresented: $showEmergency) {
                EmergencyCravingView()
            }
            .sensoryFeedback(.success, trigger: viewModel.showReadyHaptic)
            .onAppear(perform: setupDailyGoals)
            .overlay(alignment: .bottom) {
                if showUndoBanner {
                    HStack {
                        Text("Azione registrata")
                            .font(.subheadline)
                        Spacer()
                        Button("Annulla") {
                            undoLastSmokingAction()
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .overlay {
                if pendingSmokingAction != nil {
                    ZStack {
                        Color.black.opacity(0.35)
                            .ignoresSafeArea()
                            .onTapGesture {
                                pendingSmokingAction = nil
                            }
                        VStack {
                            Spacer()
                            VStack(alignment: .leading, spacing: 12) {
                            Text("Vuoi davvero fumare?")
                                .font(.headline)
                                .foregroundStyle(.black)
                            Text(confirmationMessage())
                                .font(.subheadline)
                                .foregroundStyle(.black.opacity(0.78))
                            HStack(spacing: 10) {
                                Button("Fumo") {
                                    confirmSmokingAction()
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.red)
                                .frame(maxWidth: .infinity)

                                Button("Resisto") {
                                    handleResistFromConfirmation()
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 1.0, green: 0.98, blue: 0.93),
                                            Color(red: 0.99, green: 0.95, blue: 0.86)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8, content: content)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground).opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.black.opacity(0.04), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
    }

    private func heroCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8, content: content)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.86, blue: 0.46),
                        Color(red: 0.90, green: 0.70, blue: 0.28)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: Color(red: 0.70, green: 0.52, blue: 0.10).opacity(0.35), radius: 14, x: 0, y: 8)
            .foregroundStyle(.black.opacity(0.82))
    }

    private func statRow(_ title: String, _ value: String) -> some View {
        LabeledContent(title) {
            Text(value)
                .fontWeight(.semibold)
        }
    }

    private func formatTime(_ duration: TimeInterval) -> String {
        let seconds = Int(max(0, duration))
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return "\(h)h \(m)m"
    }

    private func formatDurationShort(seconds: Int) -> String {
        let total = max(0, seconds)
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60

        if days > 0 { return "\(days)g \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    private var recoveryMilestones: [RecoveryMilestone] {
        [
            RecoveryMilestone(
                title: "Dopo 20 minuti",
                detail: "Pressione e battito migliorano",
                after: 20 * 60
            ),
            RecoveryMilestone(
                title: "Dopo 8 ore",
                detail: "Ossigeno nel sangue migliora",
                after: 8 * 3_600
            ),
            RecoveryMilestone(
                title: "Dopo 48 ore",
                detail: "Nicotina quasi eliminata",
                after: 48 * 3_600
            ),
            RecoveryMilestone(
                title: "Dopo 2 settimane",
                detail: "Circolazione migliora",
                after: 14 * 86_400
            )
        ]
    }

    private func setupDailyGoals() {
        dailyGoals = DailyGoalsCatalog.goalsForToday()
        loadGoalState()
        loadGoalMeta()
    }

    private func goalsStorageKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return "daily_goals_completed_" + f.string(from: Date())
    }

    private func loadGoalState() {
        let key = goalsStorageKey()
        let stored = UserDefaults.standard.stringArray(forKey: key) ?? []
        let validIDs = Set(dailyGoals.map(\.id))
        completedGoalIDs = Set(stored).intersection(validIDs)
        saveGoalState()
    }

    private func saveGoalState() {
        UserDefaults.standard.set(Array(completedGoalIDs), forKey: goalsStorageKey())
    }

    private func toggleGoal(_ id: String) {
        let wasAllDone = isAllGoalsDone
        if completedGoalIDs.contains(id) {
            completedGoalIDs.remove(id)
        } else {
            completedGoalIDs.insert(id)
        }
        saveGoalState()

        if !wasAllDone && isAllGoalsDone {
            registerGoalsDayCompletionIfNeeded()
        }
    }

    private var isAllGoalsDone: Bool {
        !dailyGoals.isEmpty && completedGoalsCount == dailyGoals.count
    }

    private var completedGoalsCount: Int {
        let validIDs = Set(dailyGoals.map(\.id))
        return completedGoalIDs.intersection(validIDs).count
    }

    private func difficultyColor(_ difficulty: GoalDifficulty) -> Color {
        switch difficulty {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }

    private func loadGoalMeta() {
        goalsStreak = UserDefaults.standard.integer(forKey: "daily_goals_streak")
        goalsDaysCompleted = UserDefaults.standard.integer(forKey: "daily_goals_days_completed")
    }

    private func todayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private func yesterdayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return f.string(from: yesterday)
    }

    private func registerGoalsDayCompletionIfNeeded() {
        let completedTodayKey = "daily_goals_completed_day"
        let already = UserDefaults.standard.string(forKey: completedTodayKey)
        let today = todayKey()
        if already == today { return }

        let lastCompletion = UserDefaults.standard.string(forKey: "daily_goals_last_completion")
        if lastCompletion == yesterdayKey() {
            goalsStreak += 1
        } else {
            goalsStreak = 1
        }
        goalsDaysCompleted += 1

        UserDefaults.standard.set(today, forKey: completedTodayKey)
        UserDefaults.standard.set(today, forKey: "daily_goals_last_completion")
        UserDefaults.standard.set(goalsStreak, forKey: "daily_goals_streak")
        UserDefaults.standard.set(goalsDaysCompleted, forKey: "daily_goals_days_completed")
    }

    private func confirmationMessage() -> String {
        if let nextGoal = dailyGoals.first(where: { !completedGoalIDs.contains($0.id) }) {
            return "Se resisti puoi completare: \"\(nextGoal.text)\"."
        }
        return "Se resisti fai comunque un passo avanti."
    }

    private func confirmSmokingAction() {
        guard let action = pendingSmokingAction else { return }
        lastProfileSnapshot = viewModel.snapshotProfile()
        pendingSmokingAction = nil

        switch action {
        case .onTime:
            viewModel.smokedOnTime()
        case .early:
            viewModel.smokedEarly()
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            showUndoBanner = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showUndoBanner = false
            }
            lastProfileSnapshot = nil
        }
    }

    private func undoLastSmokingAction() {
        guard let snapshot = lastProfileSnapshot else { return }
        viewModel.restoreProfile(snapshot)
        withAnimation(.easeInOut(duration: 0.2)) {
            showUndoBanner = false
        }
        lastProfileSnapshot = nil
    }

    private func handleResistFromConfirmation() {
        pendingSmokingAction = nil
        if viewModel.timerFinished {
            viewModel.resist()
        }
    }

}
