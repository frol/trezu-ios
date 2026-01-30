import SwiftUI

struct ContentView: View {
    @Environment(WalletManager.self) private var walletManager
    @State private var selectedTreasury: Treasury?

    var body: some View {
        Group {
            if let treasury = selectedTreasury {
                TreasuryTabView(treasury: treasury, onBack: {
                    selectedTreasury = nil
                })
            } else {
                HomeView(onSelectTreasury: { treasury in
                    selectedTreasury = treasury
                })
            }
        }
        .animation(.easeInOut, value: selectedTreasury?.id)
    }
}

struct TreasuryTabView: View {
    let treasury: Treasury
    let onBack: () -> Void

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(treasury: treasury, onBack: onBack)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.pie")
                }
                .tag(0)

            ProposalsListView(treasury: treasury)
                .tabItem {
                    Label("Proposals", systemImage: "doc.text")
                }
                .tag(1)

            MembersListView(treasury: treasury)
                .tabItem {
                    Label("Members", systemImage: "person.3")
                }
                .tag(2)
        }
    }
}

#Preview {
    ContentView()
        .environment(WalletManager.shared)
        .environment(TreasuryAPIClient.shared)
}
