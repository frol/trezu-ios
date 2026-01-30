import SwiftUI

struct ConnectWalletPrompt: View {
    let message: String
    let onConnect: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "wallet.pass")
                    .font(.system(size: 36))
                    .foregroundStyle(.blue)
            }

            // Title
            Text("Wallet Required")
                .font(.title3)
                .fontWeight(.bold)

            // Message
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button("Connect Wallet") {
                    onConnect()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 8)
        }
        .padding(24)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 16, y: 4)
        .padding()
    }
}

// MARK: - Full Screen Prompt

struct ConnectWalletSheet: View {
    @Environment(WalletManager.self) private var walletManager
    @Binding var isPresented: Bool
    let message: String
    var onConnected: (() -> Void)?

    @State private var showWebView = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 100, height: 100)

                    Image(systemName: "wallet.pass")
                        .font(.system(size: 44))
                        .foregroundStyle(.blue)
                }

                // Title and message
                VStack(spacing: 12) {
                    Text("Connect Your Wallet")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                // Connect button
                Button {
                    showWebView = true
                } label: {
                    HStack {
                        Image(systemName: "wallet.pass")
                        Text("Connect Wallet")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Text("Connect your NEAR wallet to perform this action")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Spacer()
            }
            .padding()
            .navigationTitle("Wallet Required")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .sheet(isPresented: $showWebView) {
                WalletWebViewSheet(isPresented: $showWebView)
            }
            .onChange(of: walletManager.isConnected) { _, isConnected in
                if isConnected {
                    isPresented = false
                    onConnected?()
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - View Modifier

struct WalletRequiredModifier: ViewModifier {
    @Environment(WalletManager.self) private var walletManager
    @Binding var showPrompt: Bool
    let message: String
    var onConnected: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showPrompt) {
                ConnectWalletSheet(
                    isPresented: $showPrompt,
                    message: message,
                    onConnected: onConnected
                )
            }
    }
}

extension View {
    func walletRequired(
        isPresented: Binding<Bool>,
        message: String,
        onConnected: (() -> Void)? = nil
    ) -> some View {
        modifier(WalletRequiredModifier(
            showPrompt: isPresented,
            message: message,
            onConnected: onConnected
        ))
    }
}

// MARK: - Read-Only Badge

struct ReadOnlyBadge: View {
    let reason: String?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "eye")
                .font(.caption2)

            Text("View Only")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray5))
        .clipShape(Capsule())
        .help(reason ?? "Connect wallet to perform actions")
    }
}

#Preview("Prompt Card") {
    ZStack {
        Color.black.opacity(0.3)
            .ignoresSafeArea()

        ConnectWalletPrompt(
            message: "Connect your wallet to vote on this proposal",
            onConnect: {},
            onCancel: {}
        )
    }
}

#Preview("Sheet") {
    Text("Main Content")
        .sheet(isPresented: .constant(true)) {
            ConnectWalletSheet(
                isPresented: .constant(true),
                message: "Connect your wallet to vote on proposals"
            )
            .environment(WalletManager.shared)
        }
}

#Preview("Badge") {
    VStack(spacing: 20) {
        ReadOnlyBadge(reason: nil)
        ReadOnlyBadge(reason: "You are not a member of this treasury")
    }
    .padding()
}
