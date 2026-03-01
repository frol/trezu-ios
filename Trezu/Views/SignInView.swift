import SwiftUI
import NEARConnect

struct SignInView: View {
    @Environment(AuthService.self) private var authService
    @EnvironmentObject private var walletManager: NEARWalletManager

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Logo and branding
            VStack(spacing: 16) {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)

                Text("Trezu")
                    .font(.largeTitle.bold())

                Text("Multi-sig Treasury Management\nfor NEAR DAOs")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Sign in section
            VStack(spacing: 16) {
                Button {
                    Task {
                        await authService.signIn(walletManager: walletManager)
                    }
                } label: {
                    HStack(spacing: 8) {
                        if authService.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "wallet.bifold")
                            Text("Sign In with NEAR Wallet")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.tint)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(authService.isLoading || walletManager.isBusy)

                if walletManager.isSignedIn, let account = walletManager.currentAccount {
                    Label(account.displayName, systemImage: "person.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let error = authService.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 32)

            Spacer()
                .frame(height: 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}
