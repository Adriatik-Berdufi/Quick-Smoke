import Foundation
import SwiftUI
import Combine
import UserNotifications

enum ChallengeMode: String, CaseIterable, Codable, Identifiable {
    case graduale
    case medio
    case intenso

    var id: String { rawValue }

    var stepDays: Int {
        switch self {
        case .graduale: return 14
        case .medio: return 10
        case .intenso: return 7
        }
    }

    var title: String {
        switch self {
        case .graduale: return "Graduale"
        case .medio: return "Medio"
        case .intenso: return "Intenso"
        }
    }
}

struct DailyStats: Codable {
    var smoked: Int = 0
    var smokedEarly: Int = 0
    var resisted: Int = 0
}

enum ActionEventType: String, Codable {
    case smoked
    case resisted
}

struct ActionEvent: Codable, Identifiable {
    let id: UUID
    let date: Date
    let type: ActionEventType

    init(id: UUID = UUID(), date: Date, type: ActionEventType) {
        self.id = id
        self.date = date
        self.type = type
    }
}

struct ChallengeProfile: Codable {
    var cigarettesPerDay: Int
    var sleepHours: Double
    var wakeHour: Int
    var wakeMinute: Int
    var sleepHour: Int
    var sleepMinute: Int
    var challengeStartDate: Date
    var mode: ChallengeMode
    var currentIntervalMinutes: Int
    var lastCigaretteDate: Date?
    var nextAllowedCigaretteDate: Date
    var cigarettesPerPack: Int
    var packPrice: Double
    var motivation: String
    var onboardingCompleted: Bool
    var dailyStats: [String: DailyStats]
    var totalResisted: Int
    var actionEvents: [ActionEvent]?
}

@MainActor
final class ChallengeViewModel: ObservableObject {
    @Published var profile: ChallengeProfile?
    @Published var now = Date()
    @Published var showReadyHaptic = false

    private let storageKey = "smokeless.profile"
    private let center = UNUserNotificationCenter.current()
    private var timer: Timer?

    init() {
        load()
        startClock()
    }

    deinit {
        timer?.invalidate()
    }

    var needsOnboarding: Bool {
        profile?.onboardingCompleted != true
    }

    var remainingSeconds: Int {
        guard let profile else { return 0 }
        return max(0, Int(profile.nextAllowedCigaretteDate.timeIntervalSince(now)))
    }

    var timerFinished: Bool {
        remainingSeconds == 0
    }

    var challengeDay: Int {
        guard let profile else { return 1 }
        return max(1, Calendar.current.dateComponents([.day], from: profile.challengeStartDate, to: now).day ?? 0 + 1)
    }

    var nextStepInDays: Int {
        guard let profile else { return 0 }
        let passed = max(0, Calendar.current.dateComponents([.day], from: profile.challengeStartDate, to: now).day ?? 0)
        let days = profile.mode.stepDays
        return days - (passed % days)
    }

    var currentIntervalMinutes: Int {
        profile?.currentIntervalMinutes ?? 60
    }

    var levelTitle: String {
        let d = challengeDay
        let r = profile?.totalResisted ?? 0
        if d >= 21 || r >= 25 { return "Livello 4: Libertà" }
        if d >= 14 || r >= 15 { return "Livello 3: Resistenza" }
        if d >= 7 || r >= 7 { return "Livello 2: Controllo" }
        return "Livello 1: Partenza"
    }

    var motivationalLine: String {
        if timerFinished { return "Puoi fumare ora, se ne senti davvero il bisogno." }
        return "Ogni minuto senza fumare conta."
    }

    var todayStats: DailyStats {
        guard let profile else { return DailyStats() }
        return profile.dailyStats[todayKey()] ?? DailyStats()
    }

    var moneySaved: Double {
        guard let profile else { return 0 }
        let costPerCigarette = profile.packPrice / Double(max(1, profile.cigarettesPerPack))
        return Double(profile.totalResisted) * costPerCigarette
    }

    var smokeFreeDuration: TimeInterval {
        guard let profile, let last = profile.lastCigaretteDate else {
            guard let start = profile?.challengeStartDate else { return 0 }
            return now.timeIntervalSince(start)
        }
        return now.timeIntervalSince(last)
    }

    func completeOnboarding(cigarettesPerDay: Int, sleepHours: Double, wakeTime: Date, sleepTime: Date, mode: ChallengeMode, motivation: String) {
        let wake = Calendar.current.dateComponents([.hour, .minute], from: wakeTime)
        let sleep = Calendar.current.dateComponents([.hour, .minute], from: sleepTime)
        let initialTarget = Self.targetCigarettesPerDay(
            cigarettesPerDay: cigarettesPerDay,
            mode: mode,
            stepIndex: 0
        )
        let base = Self.baseIntervalMinutes(cigarettesPerDay: initialTarget, sleepHours: sleepHours)
        let rounded = Self.roundedInitialInterval(baseMinutes: base)
        let now = Date()

        profile = ChallengeProfile(
            cigarettesPerDay: cigarettesPerDay,
            sleepHours: sleepHours,
            wakeHour: wake.hour ?? 7,
            wakeMinute: wake.minute ?? 0,
            sleepHour: sleep.hour ?? 23,
            sleepMinute: sleep.minute ?? 0,
            challengeStartDate: now,
            mode: mode,
            currentIntervalMinutes: rounded,
            lastCigaretteDate: nil,
            nextAllowedCigaretteDate: now.addingTimeInterval(intervalDurationSeconds(for: rounded)),
            cigarettesPerPack: 20,
            packPrice: 6,
            motivation: motivation,
            onboardingCompleted: true,
            dailyStats: [:],
            totalResisted: 0,
            actionEvents: []
        )
        recalculateProgression()
        scheduleNotification()
        save()
    }

    func smokedOnTime() {
        guard var p = profile else { return }
        recalculateProgression(profile: &p)
        p.lastCigaretteDate = now
        p.nextAllowedCigaretteDate = now.addingTimeInterval(intervalDurationSeconds(for: p.currentIntervalMinutes))
        var stats = p.dailyStats[todayKey()] ?? DailyStats()
        stats.smoked += 1
        p.dailyStats[todayKey()] = stats
        var events = p.actionEvents ?? []
        events.append(ActionEvent(date: now, type: .smoked))
        p.actionEvents = events
        profile = p
        scheduleNotification()
        save()
    }

    func smokedEarly() {
        guard var p = profile else { return }
        recalculateProgression(profile: &p)
        let remaining = max(0, p.nextAllowedCigaretteDate.timeIntervalSince(now))
        let base = intervalDurationSeconds(for: p.currentIntervalMinutes)
        p.lastCigaretteDate = now
        p.nextAllowedCigaretteDate = now.addingTimeInterval(base + remaining)
        var stats = p.dailyStats[todayKey()] ?? DailyStats()
        stats.smoked += 1
        stats.smokedEarly += 1
        p.dailyStats[todayKey()] = stats
        var events = p.actionEvents ?? []
        events.append(ActionEvent(date: now, type: .smoked))
        p.actionEvents = events
        profile = p
        scheduleNotification()
        save()
    }

    func resist() {
        guard var p = profile else { return }
        recalculateProgression(profile: &p)
        p.nextAllowedCigaretteDate = now.addingTimeInterval(intervalDurationSeconds(for: p.currentIntervalMinutes))
        var stats = p.dailyStats[todayKey()] ?? DailyStats()
        stats.resisted += 1
        p.totalResisted += 1
        p.dailyStats[todayKey()] = stats
        var events = p.actionEvents ?? []
        events.append(ActionEvent(date: now, type: .resisted))
        p.actionEvents = events
        profile = p
        scheduleNotification()
        save()
    }

    func updateSettings(cigarettesPerDay: Int, sleepHours: Double, wakeTime: Date, sleepTime: Date, packPrice: Double, cigarettesPerPack: Int, mode: ChallengeMode, motivation: String) {
        let wake = Calendar.current.dateComponents([.hour, .minute], from: wakeTime)
        let sleep = Calendar.current.dateComponents([.hour, .minute], from: sleepTime)
        guard var p = profile else {
            let initialTarget = Self.targetCigarettesPerDay(
                cigarettesPerDay: cigarettesPerDay,
                mode: mode,
                stepIndex: 0
            )
            let base = Self.baseIntervalMinutes(cigarettesPerDay: initialTarget, sleepHours: sleepHours)
            let rounded = Self.roundedInitialInterval(baseMinutes: base)
            let now = Date()
            profile = ChallengeProfile(
                cigarettesPerDay: cigarettesPerDay,
                sleepHours: sleepHours,
                wakeHour: wake.hour ?? 7,
                wakeMinute: wake.minute ?? 0,
                sleepHour: sleep.hour ?? 23,
                sleepMinute: sleep.minute ?? 0,
                challengeStartDate: now,
                mode: mode,
                currentIntervalMinutes: rounded,
                lastCigaretteDate: nil,
                nextAllowedCigaretteDate: now.addingTimeInterval(intervalDurationSeconds(for: rounded)),
                cigarettesPerPack: cigarettesPerPack,
                packPrice: packPrice,
                motivation: motivation,
                onboardingCompleted: true,
                dailyStats: [:],
                totalResisted: 0,
                actionEvents: []
            )
            recalculateProgression()
            scheduleNotification()
            save()
            return
        }
        p.cigarettesPerDay = cigarettesPerDay
        p.sleepHours = sleepHours
        p.wakeHour = wake.hour ?? p.wakeHour
        p.wakeMinute = wake.minute ?? p.wakeMinute
        p.sleepHour = sleep.hour ?? p.sleepHour
        p.sleepMinute = sleep.minute ?? p.sleepMinute
        p.packPrice = packPrice
        p.cigarettesPerPack = cigarettesPerPack
        p.mode = mode
        p.motivation = motivation
        recalculateProgression(profile: &p)
        profile = p
        save()
    }

    func resetChallenge() {
        profile = nil
        center.removeAllPendingNotificationRequests()
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    func requestNotificationPermission() {
        Task {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
    }

    func formattedRemaining() -> String {
        let s = max(0, remainingSeconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        return String(format: "%02d:%02d:%02d", h, m, sec)
    }

    func intervalLabel(minutes: Int? = nil) -> String {
        let total = minutes ?? currentIntervalMinutes
        let h = total / 60
        let m = total % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }

    func motivationText() -> String {
        guard let text = profile?.motivation.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return "Una ricaduta non cancella i progressi."
        }
        return "Ricordati perché hai iniziato: \(text)"
    }

    func snapshotProfile() -> ChallengeProfile? {
        profile
    }

    func restoreProfile(_ snapshot: ChallengeProfile) {
        profile = snapshot
        scheduleNotification()
        save()
    }

    func exportProfileData() throws -> Data {
        guard let profile else {
            throw NSError(domain: "QuickSmoke", code: 1, userInfo: [NSLocalizedDescriptionKey: "Nessun profilo da esportare."])
        }
        return try JSONEncoder().encode(profile)
    }

    func importProfileData(_ data: Data) throws {
        guard !data.isEmpty else {
            throw NSError(domain: "QuickSmoke", code: 2, userInfo: [NSLocalizedDescriptionKey: "File backup vuoto o non valido."])
        }
        let imported = try JSONDecoder().decode(ChallengeProfile.self, from: data)
        profile = imported
        recalculateProgression()
        scheduleNotification()
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(ChallengeProfile.self, from: data) else {
            profile = nil
            return
        }
        profile = decoded
        recalculateProgression()
    }

    private func save() {
        guard let profile, let data = try? JSONEncoder().encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func startClock() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let before = self.timerFinished
                self.now = Date()
                self.recalculateProgression()
                if !before && self.timerFinished {
                    self.showReadyHaptic.toggle()
                }
            }
        }
    }

    private func recalculateProgression() {
        guard var p = profile else { return }
        recalculateProgression(profile: &p)
        profile = p
        save()
    }

    private func recalculateProgression(profile: inout ChallengeProfile) {
        let days = max(0, Calendar.current.dateComponents([.day], from: profile.challengeStartDate, to: now).day ?? 0)
        let step = days / profile.mode.stepDays
        let target = Self.targetCigarettesPerDay(
            cigarettesPerDay: profile.cigarettesPerDay,
            mode: profile.mode,
            stepIndex: step
        )
        let base = Self.baseIntervalMinutes(cigarettesPerDay: target, sleepHours: profile.sleepHours)
        profile.currentIntervalMinutes = Self.roundedInitialInterval(baseMinutes: base)
    }

    private static func baseIntervalMinutes(cigarettesPerDay: Int, sleepHours: Double) -> Int {
        let awakeHours = max(1, 24 - sleepHours)
        let base = (awakeHours * 60) / Double(max(1, cigarettesPerDay))
        return Int(base.rounded())
    }

    private static func roundedInitialInterval(baseMinutes: Int) -> Int {
        let step = 5
        let rounded = Int((Double(baseMinutes) / Double(step)).rounded()) * step
        if rounded < 20 { return 20 }
        return rounded
    }

    private static func firstReductionRate(for mode: ChallengeMode) -> Double {
        switch mode {
        case .graduale: return 0.15
        case .medio: return 0.25
        case .intenso: return 0.35
        }
    }

    private static func subsequentReductionRate(for mode: ChallengeMode) -> Double {
        switch mode {
        case .graduale: return 0.10
        case .medio: return 0.20
        case .intenso: return 0.30
        }
    }

    private static func targetCigarettesPerDay(cigarettesPerDay: Int, mode: ChallengeMode, stepIndex: Int) -> Int {
        var current = Double(max(1, cigarettesPerDay))
        current = floor(current * (1 - firstReductionRate(for: mode)))
        if current < 1 { return 1 }

        let extraIterations = max(0, stepIndex)
        let extraRate = subsequentReductionRate(for: mode)
        for _ in 0..<extraIterations {
            current = floor(current * (1 - extraRate))
            if current < 1 { return 1 }
        }
        return max(1, Int(current))
    }

    private func scheduleNotification() {
        guard let profile else { return }
        center.removePendingNotificationRequests(withIdentifiers: ["smoke_timer_done"])

        let interval = profile.nextAllowedCigaretteDate.timeIntervalSinceNow
        guard interval > 1 else { return }

        let content = UNMutableNotificationContent()
        content.title = "SmokeLess Challenge"
        content.body = "Timer finito. Puoi fumare, ma se resisti hai gia vinto un altro passo."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: "smoke_timer_done", content: content, trigger: trigger)
        center.add(request)
    }

    private func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: now)
    }

    private func intervalDurationSeconds(for minutes: Int) -> TimeInterval {
        return TimeInterval(minutes * 60)
    }
}
