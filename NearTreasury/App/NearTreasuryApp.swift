import SwiftUI

@main
struct NearTreasuryApp: App {
    @State private var walletManager = WalletManager.shared
    @State private var apiClient = TreasuryAPIClient.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(walletManager)
                .environment(apiClient)
        }
    }
}
