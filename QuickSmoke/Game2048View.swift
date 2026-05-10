import SwiftUI

private struct Game2048Snapshot: Codable, Equatable {
    let gameID: String?
    let board: [[Int]]
    let score: Int
    let isGameOver: Bool
    let won: Bool
}

private struct Saved2048Package: Codable {
    let current: Game2048Snapshot
    let undoStack: [Game2048Snapshot]
    let bestScore: Int
    let lives: Int
    let activeHistory: [Game2048Snapshot]
    let finishedHistory: [Game2048Snapshot]
}

struct Game2048View: View {
    @Environment(\.dismiss) private var dismiss

    @State private var board: [[Int]] = Array(repeating: Array(repeating: 0, count: 4), count: 4)
    @State private var score = 0
    @State private var isGameOver = false
    @State private var won = false

    @State private var bestScore = 0
    @State private var lives = 5
    @State private var currentGameID = UUID().uuidString
    @State private var undoStack: [Game2048Snapshot] = []
    @State private var activeHistory: [Game2048Snapshot] = []
    @State private var finishedHistory: [Game2048Snapshot] = []
    @State private var showSavedGames = false

    private let saveKey = "game2048.package"

    var body: some View {
        GeometryReader { geo in
            let sidePadding: CGFloat = 16
            let containerWidth = max(260, geo.size.width - (sidePadding * 2))
            let boardWidth = min(520, containerWidth * 0.95)
            let spacing: CGFloat = 8
            let tileSize = max(44, (boardWidth - (spacing * 3) - 16) / 4)

            VStack(spacing: 14) {
                HStack {
                    Text("Score: \(score)")
                        .fontWeight(.semibold)
                    Spacer()
                    Text("Record: \(bestScore)")
                        .fontWeight(.semibold)
                }

                VStack(spacing: spacing) {
                    ForEach(0..<4, id: \.self) { r in
                        HStack(spacing: spacing) {
                            ForEach(0..<4, id: \.self) { c in
                                tile(value: board[r][c], size: tileSize)
                            }
                        }
                    }
                }
                .frame(width: boardWidth)
                .padding(8)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                .highPriorityGesture(boardSwipeGesture)

                if won {
                    Text("Hai raggiunto 2048!")
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                }

                if isGameOver {
                    Text("Game Over")
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)
                }

                Button {
                    undoOneMove()
                } label: {
                    Text("Torna indietro (vite: \(lives))")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(undoStack.isEmpty || lives <= 0)

                Button("Partite salvate") {
                    showSavedGames = true
                }
                .buttonStyle(.bordered)

                Text("Scorri sulla griglia per muovere le caselle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 6)

                Button("Nuova partita") {
                    startGame(resetLives: false)
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, sidePadding)
            .padding(.vertical)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle("2048")
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Indietro") { dismiss() }
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .interactiveDismissDisabled()
            .onAppear(perform: loadOrStartGame)
            .onDisappear(perform: saveGame)
            .sheet(isPresented: $showSavedGames) {
                savedGamesSheet
            }
        }
    }

    private func tile(value: Int, size: CGFloat) -> some View {
        let fontSize = value >= 1024 ? size * 0.24 : size * 0.32
        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(tileColor(value))
                .frame(width: size, height: size)
            Text(value == 0 ? "" : "\(value)")
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .foregroundStyle(value <= 4 ? .black : .white)
        }
    }

    private var savedGamesSheet: some View {
        NavigationStack {
            List {
                Section("Partite attive") {
                    if activeHistory.isEmpty {
                        Text("Nessuna partita attiva salvata")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(activeHistory.enumerated()), id: \.offset) { _, state in
                            Button {
                                loadSnapshot(state)
                                showSavedGames = false
                            } label: {
                                HStack {
                                    Text("Score \(state.score)")
                                    Spacer()
                                    Text("Continua")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section("Partite game over") {
                    if finishedHistory.isEmpty {
                        Text("Nessuna partita game over salvata")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(finishedHistory.enumerated()), id: \.offset) { _, state in
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Score \(state.score)")
                                    .fontWeight(.semibold)
                                Button(lives > 0 ? "Riprendi con 1 vita" : "Vite finite") {
                                    resumeFromGameOver(state)
                                    showSavedGames = false
                                }
                                .buttonStyle(.bordered)
                                .disabled(lives <= 0)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Partite salvate")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Chiudi") { showSavedGames = false }
                }
            }
        }
    }

    private func startGame(resetLives: Bool) {
        currentGameID = UUID().uuidString
        board = Array(repeating: Array(repeating: 0, count: 4), count: 4)
        score = 0
        isGameOver = false
        won = false
        undoStack = []
        if resetLives { lives = 5 }
        addRandomTile()
        addRandomTile()
        saveGame()
    }

    private func moveLeft() {
        performMove { row in merge(row) }
    }

    private func moveRight() {
        performMove { row in merge(Array(row.reversed())).reversed() }
    }

    private func moveUp() {
        let before = snapshot()
        let transposed = transpose(board)
        let moved = moveRows(transposed) { row in merge(row) }
        finalizeMove(movedBoard: transpose(moved), before: before)
    }

    private func moveDown() {
        let before = snapshot()
        let transposed = transpose(board)
        let moved = moveRows(transposed) { row in merge(Array(row.reversed())).reversed() }
        finalizeMove(movedBoard: transpose(moved), before: before)
    }

    private func performMove(_ transform: ([Int]) -> [Int]) {
        let before = snapshot()
        let moved = moveRows(board, transform: transform)
        finalizeMove(movedBoard: moved, before: before)
    }

    private func moveRows(_ source: [[Int]], transform: ([Int]) -> [Int]) -> [[Int]] {
        source.map(transform)
    }

    private func finalizeMove(movedBoard newBoard: [[Int]], before: Game2048Snapshot) {
        guard newBoard != board else { return }
        undoStack.append(before)
        board = newBoard
        addRandomTile()
        won = board.flatMap { $0 }.contains(2048)
        isGameOver = !canMove()
        bestScore = max(bestScore, score)
        saveGame()
    }

    private func undoOneMove() {
        guard lives > 0, let previous = undoStack.popLast() else { return }
        lives -= 1
        board = previous.board
        score = previous.score
        isGameOver = previous.isGameOver
        won = previous.won
        bestScore = max(bestScore, score)
        saveGame()
    }

    private func merge(_ row: [Int]) -> [Int] {
        let compact = row.filter { $0 != 0 }
        var result: [Int] = []
        var i = 0

        while i < compact.count {
            if i + 1 < compact.count && compact[i] == compact[i + 1] {
                let merged = compact[i] * 2
                score += merged
                result.append(merged)
                i += 2
            } else {
                result.append(compact[i])
                i += 1
            }
        }

        while result.count < 4 { result.append(0) }
        return result
    }

    private func transpose(_ matrix: [[Int]]) -> [[Int]] {
        (0..<4).map { c in (0..<4).map { r in matrix[r][c] } }
    }

    private func addRandomTile() {
        var empties: [(Int, Int)] = []
        for r in 0..<4 {
            for c in 0..<4 where board[r][c] == 0 {
                empties.append((r, c))
            }
        }
        guard let pick = empties.randomElement() else { return }
        board[pick.0][pick.1] = Int.random(in: 0..<10) < 9 ? 2 : 4
    }

    private func canMove() -> Bool {
        for r in 0..<4 {
            for c in 0..<4 {
                if board[r][c] == 0 { return true }
                if r < 3 && board[r][c] == board[r + 1][c] { return true }
                if c < 3 && board[r][c] == board[r][c + 1] { return true }
            }
        }
        return false
    }

    private func tileColor(_ value: Int) -> Color {
        switch value {
        case 0: return Color(uiColor: .tertiarySystemBackground)
        case 2: return Color(red: 0.93, green: 0.89, blue: 0.85)
        case 4: return Color(red: 0.93, green: 0.87, blue: 0.78)
        case 8: return Color(red: 0.95, green: 0.69, blue: 0.47)
        case 16: return Color(red: 0.95, green: 0.58, blue: 0.39)
        case 32: return Color(red: 0.95, green: 0.48, blue: 0.37)
        case 64: return Color(red: 0.95, green: 0.37, blue: 0.23)
        case 128: return Color(red: 0.93, green: 0.81, blue: 0.45)
        case 256: return Color(red: 0.93, green: 0.80, blue: 0.38)
        case 512: return Color(red: 0.93, green: 0.78, blue: 0.31)
        case 1024: return Color(red: 0.93, green: 0.77, blue: 0.24)
        default: return Color(red: 0.93, green: 0.76, blue: 0.17)
        }
    }

    private func handleSwipe(translation: CGSize) {
        guard !isGameOver else { return }
        let dx = translation.width
        let dy = translation.height
        let absX = abs(dx)
        let absY = abs(dy)
        let threshold: CGFloat = 28

        guard max(absX, absY) >= threshold else { return }
        guard abs(absX - absY) > 6 else { return }

        if absX > absY {
            dx > 0 ? moveRight() : moveLeft()
        } else {
            dy > 0 ? moveDown() : moveUp()
        }
    }

    private var boardSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 18, coordinateSpace: .local)
            .onEnded { value in
                handleSwipe(translation: value.translation)
            }
    }

    private func snapshot() -> Game2048Snapshot {
        Game2048Snapshot(gameID: currentGameID, board: board, score: score, isGameOver: isGameOver, won: won)
    }

    private func loadOrStartGame() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let saved = try? JSONDecoder().decode(Saved2048Package.self, from: data) else {
            startGame(resetLives: true)
            return
        }

        board = saved.current.board
        score = saved.current.score
        isGameOver = saved.current.isGameOver
        won = saved.current.won
        currentGameID = saved.current.gameID ?? UUID().uuidString
        undoStack = saved.undoStack
        bestScore = saved.bestScore
        lives = saved.lives
        activeHistory = normalizeHistory(saved.activeHistory)
        finishedHistory = normalizeHistory(saved.finishedHistory)

        if board.flatMap({ $0 }).allSatisfy({ $0 == 0 }) {
            startGame(resetLives: false)
        }
    }

    private func saveGame() {
        let current = snapshot()

        if current.isGameOver {
            finishedHistory = upsertByGameID(state: current, in: finishedHistory)
        } else {
            activeHistory = upsertByGameID(state: current, in: activeHistory)
        }

        let package = Saved2048Package(
            current: current,
            undoStack: undoStack,
            bestScore: max(bestScore, score),
            lives: lives,
            activeHistory: Array(activeHistory.suffix(3)),
            finishedHistory: Array(finishedHistory.suffix(3))
        )

        guard let data = try? JSONEncoder().encode(package) else { return }
        UserDefaults.standard.set(data, forKey: saveKey)
    }

    private func upsertByGameID(state: Game2048Snapshot, in list: [Game2048Snapshot]) -> [Game2048Snapshot] {
        var result = list
        let id = state.gameID ?? ""
        if let index = result.lastIndex(where: { ($0.gameID ?? "") == id && !id.isEmpty }) {
            result[index] = state
        } else if result.last == state {
            result[result.count - 1] = state
        } else {
            result.append(state)
        }
        return Array(result.suffix(3))
    }

    private func normalizeHistory(_ list: [Game2048Snapshot]) -> [Game2048Snapshot] {
        var result: [Game2048Snapshot] = []
        for item in list {
            let id = item.gameID ?? ""
            if !id.isEmpty, let idx = result.lastIndex(where: { ($0.gameID ?? "") == id }) {
                result[idx] = item
                continue
            }
            if result.last != item {
                result.append(item)
            }
        }
        return Array(result.suffix(3))
    }

    private func loadSnapshot(_ state: Game2048Snapshot) {
        currentGameID = state.gameID ?? UUID().uuidString
        board = state.board
        score = state.score
        isGameOver = state.isGameOver
        won = state.won
        undoStack = []
        bestScore = max(bestScore, score)
        saveGame()
    }

    private func resumeFromGameOver(_ state: Game2048Snapshot) {
        guard lives > 0 else { return }
        lives -= 1
        currentGameID = state.gameID ?? UUID().uuidString
        board = state.board
        score = state.score
        isGameOver = false
        won = state.won
        undoStack = [state]
        bestScore = max(bestScore, score)
        saveGame()
    }
}
