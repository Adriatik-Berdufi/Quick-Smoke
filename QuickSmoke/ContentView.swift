import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ChallengeViewModel()

    var body: some View {
        MainTabView(
            viewModel: viewModel,
            initialSelection: viewModel.needsOnboarding ? 2 : 0
        )
        .onAppear {
            viewModel.requestNotificationPermission()
        }
    }
}

private struct MainTabView: View {
    @ObservedObject var viewModel: ChallengeViewModel
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var selection: Int

    init(viewModel: ChallengeViewModel, initialSelection: Int) {
        self.viewModel = viewModel
        _selection = State(initialValue: initialSelection)
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selection) {
                DashboardView(viewModel: viewModel)
                    .tag(0)

                HistoryView(viewModel: viewModel)
                    .tag(1)

                SettingsView(viewModel: viewModel)
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            if verticalSizeClass != .compact {
                HStack {
                    tabButton(title: "Dashboard", systemImage: "timer", tag: 0)
                    tabButton(title: "Progressi", systemImage: "chart.line.uptrend.xyaxis", tag: 1)
                    tabButton(title: "Impostazioni", systemImage: "gearshape", tag: 2)
                }
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 10)
                .background(.ultraThinMaterial)
            }
        }
    }

    private func tabButton(title: String, systemImage: String, tag: Int) -> some View {
        Button {
            selection = tag
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .foregroundStyle(selection == tag ? Color.accentColor : .secondary)
        }
    }
}

#Preview {
    ContentView()
}
