import SwiftUI
import NEARConnect

@main
struct TrezuApp: App {
    @StateObject private var walletManager = NEARWalletManager(
        features: [
            "signInAndSignMessage": true,
            "signDelegateActions": true,
        ]
    )
    @State private var authService = AuthService()
    @State private var treasuryService = TreasuryService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authService)
                .environment(treasuryService)
                .environmentObject(walletManager)
                .fullScreenCover(isPresented: $walletManager.showWalletUI) {
                    WalletBridgeSheet()
                        .environmentObject(walletManager)
                }
                .task {
                    await authService.checkSession()
                }
        }
    }
}
