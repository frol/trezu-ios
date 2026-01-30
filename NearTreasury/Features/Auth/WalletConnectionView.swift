import SwiftUI

struct WalletConnectionView: View {
    @Environment(WalletManager.self) private var walletManager
    @State private var viewModel = WalletConnectionViewModel()
    @State private var showWebView = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Logo and title
                VStack(spacing: 16) {
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.blue.gradient)

                    Text("NEAR Treasury")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Multi-chain crypto asset management\nwith shared control")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // Connection status
                if case .connecting = walletManager.state {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Connecting to wallet...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if let error = walletManager.lastError {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

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
                .disabled(walletManager.state == .connecting)

                // Info text
                Text("Connect your NEAR wallet to access your treasuries")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Spacer()
            }
            .padding()
            .sheet(isPresented: $showWebView) {
                WalletWebViewSheet(isPresented: $showWebView)
            }
        }
    }
}

struct WalletWebViewSheet: View {
    @Environment(WalletManager.self) private var walletManager
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            NearConnectWebViewRepresentable(
                walletManager: walletManager,
                network: "mainnet"
            )
            .navigationTitle("Connect Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .onChange(of: walletManager.isConnected) { _, isConnected in
                if isConnected {
                    isPresented = false
                }
            }
        }
    }
}

#Preview {
    WalletConnectionView()
        .environment(WalletManager.shared)
}
