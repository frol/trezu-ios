import SwiftUI
import NEARConnect

struct MainTabView: View {
    @Environment(AuthService.self) private var authService
    @Environment(TreasuryService.self) private var treasuryService
    @EnvironmentObject private var walletManager: NEARWalletManager

    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "chart.pie.fill") {
                DashboardView()
            }

            Tab("Requests", systemImage: "doc.text.fill") {
                ProposalsListView()
            }

            Tab("Members", systemImage: "person.3.fill") {
                MembersView()
            }

            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
    }
}
