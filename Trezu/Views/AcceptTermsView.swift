import SwiftUI
import NEARConnect

struct AcceptTermsView: View {
    @Environment(AuthService.self) private var authService
    @EnvironmentObject private var walletManager: NEARWalletManager
    @State private var isAccepting = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "doc.text.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("Terms of Service")
                .font(.title.bold())

            Text("Please accept the Terms of Service to continue using Trezu.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Task {
                        isAccepting = true
                        do {
                            try await authService.acceptTerms()
                        } catch {
                            self.error = error.localizedDescription
                        }
                        isAccepting = false
                    }
                } label: {
                    HStack {
                        if isAccepting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Accept & Continue")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.tint)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isAccepting)

                Button("Sign Out") {
                    Task { await authService.signOut(walletManager: walletManager) }
                }
                .foregroundStyle(.secondary)

                if let error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}
