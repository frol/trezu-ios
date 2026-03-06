import SwiftUI
import NEARConnect

// MARK: - Root View (Auth Router)

struct RootView: View {
    @Environment(AuthService.self) private var authService
    @EnvironmentObject private var walletManager: NEARWalletManager

    var body: some View {
        Group {
            if authService.isAuthenticated {
                if authService.needsTermsAcceptance {
                    AcceptTermsView()
                } else {
                    TreasuryRootView()
                }
            } else {
                SignInView()
            }
        }
        .animation(.default, value: authService.isAuthenticated)
    }
}

// MARK: - Treasury Root (Selector + Main)

struct TreasuryRootView: View {
    @Environment(AuthService.self) private var authService
    @Environment(TreasuryService.self) private var treasuryService
    @EnvironmentObject private var walletManager: NEARWalletManager

    var body: some View {
        Group {
            if treasuryService.selectedTreasury != nil {
                MainTabView()
            } else if treasuryService.isLoading {
                ProgressView("Loading treasuries...")
            } else if treasuryService.treasuries.isEmpty {
                VStack(spacing: 20) {
                    ContentUnavailableView(
                        "No Treasuries",
                        systemImage: "building.columns",
                        description: Text("You don't have access to any treasuries yet.")
                    )

                    Button {
                        Task { await authService.signOut(walletManager: walletManager) }
                    } label: {
                        Label("Sign in with a Different Account", systemImage: "person.crop.circle.badge.plus")
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                ProgressView()
            }
        }
        .task {
            treasuryService.accountId = authService.currentUser?.accountId
            await treasuryService.loadTreasuries()
            await treasuryService.autoSelectTreasuryIfNeeded()
        }
    }
}
