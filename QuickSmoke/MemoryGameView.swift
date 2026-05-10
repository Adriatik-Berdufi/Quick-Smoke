import SwiftUI

struct MemoryCard: Identifiable {
    let id = UUID()
    let symbol: String
    var isFaceUp = false
    var isMatched = false
}

struct MemoryGameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var cards: [MemoryCard] = []
    @State private var selectedIndices: [Int] = []
    @State private var moves = 0
    @State private var pairsFound = 0
    @State private var lockBoard = false

    private let symbols = ["🍎", "🚗", "⭐️", "🎵", "🐶", "⚽️"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Memory")
                .font(.title2.bold())

            Text("Mosse: \(moves) • Coppie: \(pairsFound)/\(symbols.count)")
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(cards.indices, id: \.self) { index in
                    Button {
                        flipCard(at: index)
                    } label: {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(cardColor(for: cards[index]))
                            .frame(height: 70)
                            .overlay(
                                Text(cards[index].isFaceUp || cards[index].isMatched ? cards[index].symbol : "?")
                                    .font(.system(size: 28))
                            )
                    }
                    .disabled(lockBoard || cards[index].isMatched || cards[index].isFaceUp)
                }
            }

            if pairsFound == symbols.count {
                Text("Bravo! Hai completato il Memory.")
                    .fontWeight(.semibold)
            }

            Button("Nuova partita") {
                setupGame()
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
        .onAppear(perform: setupGame)
    }

    private func setupGame() {
        var deck = symbols.flatMap { [MemoryCard(symbol: $0), MemoryCard(symbol: $0)] }
        deck.shuffle()
        cards = deck
        selectedIndices = []
        moves = 0
        pairsFound = 0
        lockBoard = false
    }

    private func flipCard(at index: Int) {
        guard selectedIndices.count < 2 else { return }
        cards[index].isFaceUp = true
        selectedIndices.append(index)

        if selectedIndices.count == 2 {
            moves += 1
            evaluatePair()
        }
    }

    private func evaluatePair() {
        let first = selectedIndices[0]
        let second = selectedIndices[1]

        if cards[first].symbol == cards[second].symbol {
            cards[first].isMatched = true
            cards[second].isMatched = true
            pairsFound += 1
            selectedIndices = []
            return
        }

        lockBoard = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            cards[first].isFaceUp = false
            cards[second].isFaceUp = false
            selectedIndices = []
            lockBoard = false
        }
    }

    private func cardColor(for card: MemoryCard) -> Color {
        if card.isMatched { return Color.green.opacity(0.3) }
        if card.isFaceUp { return Color(uiColor: .secondarySystemBackground) }
        return Color(uiColor: .tertiarySystemBackground)
    }
}
