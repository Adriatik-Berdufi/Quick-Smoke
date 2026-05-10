import SwiftUI

private struct AppBadge: Identifiable {
    let id: String
    let title: String
    let isUnlocked: Bool
}

struct BadgeRecordsView: View {
    @ObservedObject var viewModel: ChallengeViewModel
    @State private var showAllLockedBadges = false
    @State private var showAllUnlockedBadges = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if let profile = viewModel.profile {
                    let badges = allBadges(profile: profile)
                    let unlocked = badges.filter(\.isUnlocked)
                    let locked = badges.filter { !$0.isUnlocked }

                    card {
                        HStack {
                            Text("Badge raggiunti")
                                .font(.headline)
                            Spacer()
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showAllUnlockedBadges.toggle()
                                }
                            } label: {
                                Image(systemName: showAllUnlockedBadges ? "chevron.up" : "chevron.down")
                            }
                            .buttonStyle(.bordered)
                        }

                        if unlocked.isEmpty {
                            Text("Nessun badge sbloccato per ora.")
                                .foregroundStyle(.secondary)
                        } else {
                            let visibleUnlocked = showAllUnlockedBadges ? unlocked : Array(unlocked.prefix(3))
                            ForEach(visibleUnlocked) { badge in
                                badgeRow(badge.title, unlocked: true)
                            }
                            if !showAllUnlockedBadges && unlocked.count > 3 {
                                Text("+\(unlocked.count - 3) altri badge")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    card {
                        HStack {
                            Text("Badge da raggiungere")
                                .font(.headline)
                            Spacer()
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showAllLockedBadges.toggle()
                                }
                            } label: {
                                Image(systemName: showAllLockedBadges ? "chevron.up" : "chevron.down")
                            }
                            .buttonStyle(.bordered)
                        }

                        let visibleLocked = showAllLockedBadges ? locked : Array(locked.prefix(3))
                        ForEach(visibleLocked) { badge in
                            badgeRow(badge.title, unlocked: false)
                        }
                        if !showAllLockedBadges && locked.count > 3 {
                            Text("+\(locked.count - 3) altri badge")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    card {
                        Text("Record")
                            .font(.headline)
                        LabeledContent("Giorno sfida") { Text("\(viewModel.challengeDay)") }
                        LabeledContent("Totale sigarette evitate") { Text("\(profile.totalResisted)") }
                        LabeledContent("Livello") { Text(viewModel.levelTitle) }
                        LabeledContent("Intervallo attuale") { Text(viewModel.intervalLabel()) }
                        LabeledContent("Soldi risparmiati") { Text(viewModel.moneySaved.formatted(.currency(code: "EUR"))) }
                        LabeledContent("Tempo senza fumare") { Text(formatDuration(viewModel.smokeFreeDuration)) }
                        LabeledContent("Miglior giornata (evitate)") { Text("\(bestResistedDay(from: profile.dailyStats))") }
                        LabeledContent("Fumate oggi") { Text("\(viewModel.todayStats.smoked)") }
                        LabeledContent("Evitate oggi") { Text("\(viewModel.todayStats.resisted)") }
                    }

                    card {
                        Text("Record obiettivi giornalieri")
                            .font(.headline)
                        LabeledContent("Streak obiettivi") { Text("\(goalsStreak) giorni") }
                        LabeledContent("Giorni obiettivi completati") { Text("\(goalsDaysCompleted)") }
                        LabeledContent("Obiettivi completati oggi") { Text("\(todayGoalsCompletedCount)") }
                    }
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Record")
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8, content: content)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
    }

    private func badgeRow(_ name: String, unlocked: Bool) -> some View {
        HStack {
            Image(systemName: unlocked ? "checkmark.seal.fill" : "seal")
                .foregroundStyle(unlocked ? .green : .secondary)
            Text(name)
        }
    }

    private func allBadges(profile: ChallengeProfile) -> [AppBadge] {
        let day = viewModel.challengeDay
        let resisted = profile.totalResisted
        let today = viewModel.todayStats
        let bestDay = bestResistedDay(from: profile.dailyStats)
        let money = viewModel.moneySaved
        let smokeFreeHours = Int(max(0, viewModel.smokeFreeDuration / 3600))
        let goalsDoneToday = todayGoalsCompletedCount

        return [
            AppBadge(id: "b0", title: "Primo passo per smettere di fumare", isUnlocked: true),
            AppBadge(id: "b1", title: "Prima sigaretta evitata", isUnlocked: resisted >= 1),
            AppBadge(id: "b2", title: "Primo giorno completato", isUnlocked: day >= 2),
            AppBadge(id: "b3", title: "3 giorni di fila", isUnlocked: day >= 3),
            AppBadge(id: "b4", title: "7 giorni di fila", isUnlocked: day >= 7),
            AppBadge(id: "b5", title: "14 giorni di fila", isUnlocked: day >= 14),
            AppBadge(id: "b6", title: "30 giorni di fila", isUnlocked: day >= 30),
            AppBadge(id: "b7", title: "Primo intervallo aumentato", isUnlocked: day > profile.mode.stepDays),
            AppBadge(id: "b8", title: "10 sigarette evitate", isUnlocked: resisted >= 10),
            AppBadge(id: "b9", title: "25 sigarette evitate", isUnlocked: resisted >= 25),
            AppBadge(id: "b10", title: "50 sigarette evitate", isUnlocked: resisted >= 50),
            AppBadge(id: "b11", title: "100 sigarette evitate", isUnlocked: resisted >= 100),
            AppBadge(id: "b12", title: "Miglior giornata (5 evitate)", isUnlocked: bestDay >= 5),
            AppBadge(id: "b13", title: "Giornata pulita (0 fumate)", isUnlocked: today.smoked == 0 && day > 1),
            AppBadge(id: "b14", title: "3 resistenze in un giorno", isUnlocked: today.resisted >= 3),
            AppBadge(id: "b15", title: "Streak obiettivi 3 giorni", isUnlocked: goalsStreak >= 3),
            AppBadge(id: "b16", title: "Streak obiettivi 7 giorni", isUnlocked: goalsStreak >= 7),
            AppBadge(id: "b17", title: "Streak obiettivi 14 giorni", isUnlocked: goalsStreak >= 14),
            AppBadge(id: "b18", title: "10 giorni obiettivi completati", isUnlocked: goalsDaysCompleted >= 10),
            AppBadge(id: "b19", title: "30 giorni obiettivi completati", isUnlocked: goalsDaysCompleted >= 30),
            AppBadge(id: "b20", title: "Tutti gli obiettivi di oggi completati", isUnlocked: goalsDoneToday >= 3),
            AppBadge(id: "b21", title: "1 giorno senza fumare", isUnlocked: smokeFreeHours >= 24),
            AppBadge(id: "b22", title: "3 giorni senza fumare", isUnlocked: smokeFreeHours >= 72),
            AppBadge(id: "b23", title: "1 settimana senza fumare", isUnlocked: smokeFreeHours >= 168),
            AppBadge(id: "b24_sf", title: "2 settimane senza fumare", isUnlocked: smokeFreeHours >= 336),
            AppBadge(id: "b25_sf", title: "1 mese senza fumare", isUnlocked: smokeFreeHours >= 24 * 30),
            AppBadge(id: "b26_sf", title: "3 mesi senza fumare", isUnlocked: smokeFreeHours >= 24 * 90),
            AppBadge(id: "b27_sf", title: "6 mesi senza fumare", isUnlocked: smokeFreeHours >= 24 * 180),
            AppBadge(id: "b28_sf", title: "1 anno senza fumare", isUnlocked: smokeFreeHours >= 24 * 365),
            AppBadge(id: "b29_sf", title: "2 anni senza fumare", isUnlocked: smokeFreeHours >= 24 * 730),
            AppBadge(id: "b30_final", title: "Ho smesso di fumare", isUnlocked: smokeFreeHours >= 24 * 730),
            AppBadge(id: "b31", title: "Risparmiati 10€", isUnlocked: money >= 10),
            AppBadge(id: "b32", title: "Risparmiati 25€", isUnlocked: money >= 25),
            AppBadge(id: "b33", title: "Risparmiati 50€", isUnlocked: money >= 50),
            AppBadge(id: "b34", title: "200 sigarette evitate", isUnlocked: resisted >= 200),
            AppBadge(id: "b35", title: "500 sigarette evitate", isUnlocked: resisted >= 500),
            AppBadge(id: "b36", title: "60 giorni di sfida", isUnlocked: day >= 60),
            AppBadge(id: "b37", title: "100 giorni di sfida", isUnlocked: day >= 100)
        ]
    }

    private var goalsStreak: Int {
        UserDefaults.standard.integer(forKey: "daily_goals_streak")
    }

    private var goalsDaysCompleted: Int {
        UserDefaults.standard.integer(forKey: "daily_goals_days_completed")
    }

    private var todayGoalsCompletedCount: Int {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let key = "daily_goals_completed_" + f.string(from: Date())
        return (UserDefaults.standard.stringArray(forKey: key) ?? []).count
    }

    private func bestResistedDay(from dailyStats: [String: DailyStats]) -> Int {
        dailyStats.values.map(\.resisted).max() ?? 0
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = Int(max(0, duration))
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return "\(h)h \(m)m"
    }
}
