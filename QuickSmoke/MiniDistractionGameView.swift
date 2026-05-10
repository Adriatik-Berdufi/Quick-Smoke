import SwiftUI

enum MiniGameMode: String, CaseIterable, Identifiable {
    case singlePlayer = "Single Player"
    case twoPlayers = "2 Player"

    var id: String { rawValue }
}

struct MiniDistractionGameView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("miniGame.cpuWins") private var cpuWins = 0
    @AppStorage("miniGame.cpuLosses") private var cpuLosses = 0
    @AppStorage("miniGame.cpuDraws") private var cpuDraws = 0

    @State private var board = Array(repeating: "", count: 9)
    @State private var xTurn = true
    @State private var gameResult = ""
    @State private var mode: MiniGameMode = .singlePlayer
    @State private var winningLine: [Int] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tris")
                .font(.title2.bold())

            Picker("Modalita", selection: $mode) {
                ForEach(MiniGameMode.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: mode) { _, _ in
                resetGame()
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(0..<9, id: \.self) { index in
                    Button {
                        makeMove(index)
                    } label: {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(cellColor(for: index))
                            .frame(height: 84)
                            .overlay(
                                Text(board[index].isEmpty ? " " : board[index])
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(winningLine.contains(index) ? Color.green : Color.clear, lineWidth: 3)
                            )
                    }
                    .disabled(!board[index].isEmpty || !gameResult.isEmpty)
                }
            }

            Text(turnLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if mode == .singlePlayer {
                Text("Storico CPU • Vinte: \(cpuWins)  Perse: \(cpuLosses)  Pareggi: \(cpuDraws)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !gameResult.isEmpty {
                Text(gameResult)
                    .fontWeight(.semibold)
            }

            Button("Nuova partita") {
                resetGame()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("Mini distrazione")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Indietro") { dismiss() }
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .interactiveDismissDisabled()
    }

    private func makeMove(_ index: Int) {
        guard board[index].isEmpty, gameResult.isEmpty else { return }
        board[index] = xTurn ? "X" : "O"

        if let winner = winnerSymbol() {
            gameResult = resultText(for: winner)
            winningLine = winnerLine(on: board) ?? []
            recordResult(for: winner)
            return
        }

        if !board.contains("") {
            gameResult = "Pareggio"
            recordDraw()
            return
        }

        xTurn.toggle()

        if mode == .singlePlayer && !xTurn && gameResult.isEmpty {
            cpuMove()
        }
    }

    private var turnLabel: String {
        if !gameResult.isEmpty { return "Partita conclusa" }
        if mode == .singlePlayer {
            return xTurn ? "Tocca a te (X)" : "Turno CPU (O)"
        }
        return xTurn ? "Turno X" : "Turno O"
    }

    private func cpuMove() {
        let free = board.indices.filter { board[$0].isEmpty }
        guard !free.isEmpty else { return }
        let shouldMakeMistake = Int.random(in: 0..<100) < 25
        let choice: Int
        if shouldMakeMistake {
            choice = free.randomElement() ?? bestMove(for: board)
        } else {
            choice = bestMove(for: board)
        }
        board[choice] = "O"

        if let winner = winnerSymbol() {
            gameResult = resultText(for: winner)
            winningLine = winnerLine(on: board) ?? []
            recordResult(for: winner)
            return
        }

        if !board.contains("") {
            gameResult = "Pareggio"
            recordDraw()
            return
        }

        xTurn = true
    }

    private func bestMove(for state: [String]) -> Int {
        let available = state.indices.filter { state[$0].isEmpty }
        var bestScore = Int.min
        var move = available[0]

        for index in available {
            var next = state
            next[index] = "O"
            let score = minimax(board: next, isMaximizing: false)
            if score > bestScore {
                bestScore = score
                move = index
            }
        }
        return move
    }

    private func minimax(board state: [String], isMaximizing: Bool) -> Int {
        if let winner = winnerSymbol(on: state) {
            if winner == "O" { return 10 }
            if winner == "X" { return -10 }
        }
        if !state.contains("") { return 0 }

        let available = state.indices.filter { state[$0].isEmpty }

        if isMaximizing {
            var best = Int.min
            for index in available {
                var next = state
                next[index] = "O"
                best = max(best, minimax(board: next, isMaximizing: false))
            }
            return best
        } else {
            var best = Int.max
            for index in available {
                var next = state
                next[index] = "X"
                best = min(best, minimax(board: next, isMaximizing: true))
            }
            return best
        }
    }

    private func winnerSymbol() -> String? {
        winnerSymbol(on: board)
    }

    private func winnerSymbol(on boardState: [String]) -> String? {
        let lines = [
            [0, 1, 2], [3, 4, 5], [6, 7, 8],
            [0, 3, 6], [1, 4, 7], [2, 5, 8],
            [0, 4, 8], [2, 4, 6]
        ]

        for line in lines {
            let a = boardState[line[0]]
            if !a.isEmpty && a == boardState[line[1]] && a == boardState[line[2]] {
                return a
            }
        }
        return nil
    }

    private func winnerLine(on boardState: [String]) -> [Int]? {
        let lines = [
            [0, 1, 2], [3, 4, 5], [6, 7, 8],
            [0, 3, 6], [1, 4, 7], [2, 5, 8],
            [0, 4, 8], [2, 4, 6]
        ]
        for line in lines {
            let a = boardState[line[0]]
            if !a.isEmpty && a == boardState[line[1]] && a == boardState[line[2]] {
                return line
            }
        }
        return nil
    }

    private func cellColor(for index: Int) -> Color {
        if winningLine.contains(index) {
            return Color.green.opacity(0.22)
        }
        return Color(uiColor: .tertiarySystemBackground)
    }

    private func resetGame() {
        board = Array(repeating: "", count: 9)
        xTurn = true
        gameResult = ""
        winningLine = []
    }

    private func resultText(for winner: String) -> String {
        if mode == .singlePlayer {
            return winner == "X" ? "Hai vinto" : "Hai perso"
        }
        return "Ha vinto \(winner)"
    }

    private func recordResult(for winner: String) {
        guard mode == .singlePlayer else { return }
        if winner == "X" {
            cpuWins += 1
        } else {
            cpuLosses += 1
        }
    }

    private func recordDraw() {
        guard mode == .singlePlayer else { return }
        cpuDraws += 1
    }
}
