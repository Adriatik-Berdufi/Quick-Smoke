import SwiftUI

struct GameSelectionView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section("Scegli un gioco") {
                NavigationLink {
                    MiniDistractionGameView()
                } label: {
                    Label("Tris", systemImage: "grid")
                }

                NavigationLink {
                    MemoryGameView()
                } label: {
                    Label("Memory", systemImage: "square.grid.2x2")
                }

                NavigationLink {
                    Game2048View()
                } label: {
                    Label("2048", systemImage: "square.grid.4x3.fill")
                }
            }
        }
        .navigationTitle("Mini distrazioni")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Indietro") { dismiss() }
            }
        }
        .interactiveDismissDisabled()
    }
}
