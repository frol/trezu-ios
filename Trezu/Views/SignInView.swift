import SwiftUI
import NEARConnect

struct SignInView: View {
    @Environment(AuthService.self) private var authService
    @EnvironmentObject private var walletManager: NEARWalletManager

    var body: some View {
        ZStack(alignment: .top) {
            // Blue gradient background (top portion)
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.35, blue: 0.95),
                    Color(red: 0.25, green: 0.50, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header tagline
                Text("Cross-chain multisig\nsecurity for managing\ndigital assets")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 28)
                    .padding(.top, 60)

                Spacer()
                    .frame(height: 40)

                // White card
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 40)

                    // Logo
                    HStack(spacing: 10) {
                        // Trezu icon shape
                        TrezuLogoShape()
                            .fill(Color.accentColor)
                            .frame(width: 28, height: 31)

                        Text("trezu")
                            .font(.system(size: 28, weight: .bold))
                    }

                    Spacer()
                        .frame(height: 32)

                    // Welcome text
                    Text("Welcome to Trezu")
                        .font(.title2.bold())

                    Spacer()
                        .frame(height: 8)

                    Text("Use your wallet to sign in into your treasury.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Spacer()
                        .frame(height: 32)

                    // Connect Wallet button
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
                                Text("Connect Wallet")
                                    .font(.body.weight(.semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(.label))
                        .foregroundStyle(Color(.systemBackground))
                        .clipShape(Capsule())
                    }
                    .disabled(authService.isLoading || walletManager.isBusy)
                    .padding(.horizontal, 40)

                    if let error = authService.error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .padding(.top, 12)
                    }

                    Spacer()
                        .frame(height: 16)

                    if walletManager.isSignedIn, let account = walletManager.currentAccount {
                        Label(account.displayName, systemImage: "person.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 16)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background(
                    Color(.systemBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(color: .black.opacity(0.1), radius: 20, y: -4)
                )
                .ignoresSafeArea(edges: .bottom)
            }
        }
    }
}
// MARK: - Trezu Logo Shape

/// Renders the Trezu logo icon as a native SwiftUI Shape.
struct TrezuLogoShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        // Original SVG viewBox: 0 0 89 98
        let sx = w / 89.0
        let sy = h / 98.0

        var path = Path()
        // Bottom-right triangle: M44.13 97.72 V50.43 H88.26 L44.13 97.72
        path.move(to: CGPoint(x: 44.13 * sx, y: 97.72 * sy))
        path.addLine(to: CGPoint(x: 44.13 * sx, y: 50.43 * sy))
        path.addLine(to: CGPoint(x: 88.26 * sx, y: 50.43 * sy))
        path.closeSubpath()

        // Top parallelogram: M44.13 50.43 H0 L44.13 0 H88.26 L44.13 50.43
        path.move(to: CGPoint(x: 44.13 * sx, y: 50.43 * sy))
        path.addLine(to: CGPoint(x: 0, y: 50.43 * sy))
        path.addLine(to: CGPoint(x: 44.13 * sx, y: 0))
        path.addLine(to: CGPoint(x: 88.26 * sx, y: 0))
        path.closeSubpath()

        return path
    }
}

