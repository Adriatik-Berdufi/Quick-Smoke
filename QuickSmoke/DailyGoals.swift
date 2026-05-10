import Foundation

enum GoalDifficulty: String, CaseIterable {
    case easy
    case medium
    case hard

    var title: String {
        switch self {
        case .easy: return "Facile"
        case .medium: return "Medio"
        case .hard: return "Difficile"
        }
    }
}

struct DailyGoal: Identifiable, Hashable {
    let id: String
    let text: String
    let difficulty: GoalDifficulty
}

enum DailyGoalsCatalog {
    // Lista obiettivi facili
    static let easy: [DailyGoal] = [
        DailyGoal(id: "easy_1", text: "Aspetta 5 minuti extra una volta", difficulty: .easy),
        DailyGoal(id: "easy_2", text: "Aspetta 10 minuti extra una volta", difficulty: .easy),
        DailyGoal(id: "easy_3", text: "Riduci di 1 sigaretta rispetto a ieri", difficulty: .easy),
        DailyGoal(id: "easy_4", text: "Bevi un bicchiere d'acqua prima di fumare", difficulty: .easy),
        DailyGoal(id: "easy_5", text: "Fai 3 respiri profondi prima di accendere una sigaretta", difficulty: .easy),
        DailyGoal(id: "easy_6", text: "Non fumare appena sveglio per 15 minuti", difficulty: .easy),
        DailyGoal(id: "easy_7", text: "Non fumare mentre cammini", difficulty: .easy),
        DailyGoal(id: "easy_8", text: "Resisti a una voglia senza fumare", difficulty: .easy),
        DailyGoal(id: "easy_9", text: "Usa il pulsante 'Ho voglia di fumare' almeno una volta", difficulty: .easy),
        DailyGoal(id: "easy_10", text: "Rimani sotto il tuo limite giornaliero", difficulty: .easy)
    ]

    // Lista obiettivi medi
    static let medium: [DailyGoal] = [
        DailyGoal(id: "medium_1", text: "Aspetta 20 minuti extra una volta", difficulty: .medium),
        DailyGoal(id: "medium_2", text: "Evita 1 sigaretta dopo pranzo", difficulty: .medium),
        DailyGoal(id: "medium_3", text: "Evita la sigaretta del caffè", difficulty: .medium),
        DailyGoal(id: "medium_4", text: "Rimanda la prima sigaretta della giornata di 30 minuti", difficulty: .medium),
        DailyGoal(id: "medium_5", text: "Fai una passeggiata invece di fumare", difficulty: .medium),
        DailyGoal(id: "medium_6", text: "Non fumare in macchina oggi", difficulty: .medium),
        DailyGoal(id: "medium_7", text: "Non fumare durante una chiamata", difficulty: .medium),
        DailyGoal(id: "medium_8", text: "Riduci le sigarette serali", difficulty: .medium),
        DailyGoal(id: "medium_9", text: "Fai passare 90 minuti tra due sigarette almeno una volta", difficulty: .medium),
        DailyGoal(id: "medium_10", text: "Completa una giornata senza fumare 'automaticamente'", difficulty: .medium)
    ]

    // Lista obiettivi difficili
    static let hard: [DailyGoal] = [
        DailyGoal(id: "hard_1", text: "Evita 3 sigarette oggi", difficulty: .hard),
        DailyGoal(id: "hard_2", text: "Aspetta 2 ore tra due sigarette", difficulty: .hard),
        DailyGoal(id: "hard_3", text: "Salta completamente la sigaretta dopo cena", difficulty: .hard),
        DailyGoal(id: "hard_4", text: "Non fumare per tutta la mattina", difficulty: .hard),
        DailyGoal(id: "hard_5", text: "Non fumare dopo le 22", difficulty: .hard),
        DailyGoal(id: "hard_6", text: "Resisti a 3 craving consecutivi", difficulty: .hard),
        DailyGoal(id: "hard_7", text: "Fai una pausa stress senza sigaretta", difficulty: .hard),
        DailyGoal(id: "hard_8", text: "Nessuna sigaretta per 4 ore consecutive", difficulty: .hard),
        DailyGoal(id: "hard_9", text: "Dimezza le sigarette rispetto al tuo vecchio ritmo", difficulty: .hard),
        DailyGoal(id: "hard_10", text: "Completa una serata sociale fumando meno del solito", difficulty: .hard)
    ]

    static func goalsForToday(date: Date = Date()) -> [DailyGoal] {
        let key = dayKey(date)
        return [
            pick(from: easy, seed: key + "_e"),
            pick(from: medium, seed: key + "_m"),
            pick(from: hard, seed: key + "_h")
        ]
    }

    private static func pick(from list: [DailyGoal], seed: String) -> DailyGoal {
        guard !list.isEmpty else {
            return DailyGoal(id: "fallback", text: "Obiettivo non disponibile", difficulty: .easy)
        }
        let value = abs(seed.hashValue)
        return list[value % list.count]
    }

    private static func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
