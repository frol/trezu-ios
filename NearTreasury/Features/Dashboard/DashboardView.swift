import SwiftUI

struct DashboardView: View {
    @Environment(TreasuryAPIClient.self) private var apiClient
    @Environment(WalletManager.self) private var walletManager
    @State private var viewModel = DashboardViewModel()
    @State private var showWalletConnection = false

    let treasury: Treasury
    let onBack: () -> Void

    private var isReadOnly: Bool {
        !walletManager.isConnected
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .loading:
                    LoadingView(message: "Loading dashboard...")

                case .loaded:
                    ScrollView {
                        VStack(spacing: 24) {
                            // Read-only indicator
                            if isReadOnly {
                                readOnlyBanner
                            }

                            // Total Balance Card
                            totalBalanceCard

                            // Assets Section
                            AssetsSection(assets: viewModel.assets)

                            // Pending Requests Section
                            PendingRequestsSection(
                                proposals: viewModel.pendingProposals,
                                treasuryId: treasury.daoId
                            )

                            // Recent Activity Section
                            RecentActivitySection(activities: viewModel.recentActivities)
                        }
                        .padding()
                    }
                    .refreshable {
                        await loadData()
                    }

                case .error(let error):
                    ErrorView(error: error) {
                        Task {
                            await loadData()
                        }
                    }
                }
            }
            .navigationTitle(treasury.displayName)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onBack()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if walletManager.isConnected {
                        Menu {
                            if let accountId = walletManager.currentAccountId {
                                Section {
                                    Label(accountId, systemImage: "person.circle")
                                }
                            }

                            Button(role: .destructive) {
                                Task {
                                    try? await walletManager.disconnect()
                                }
                            } label: {
                                Label("Disconnect", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                        } label: {
                            AccountAvatar(
                                accountId: walletManager.currentAccountId ?? "",
                                size: 32
                            )
                        }
                    } else {
                        Button {
                            showWalletConnection = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "wallet.pass")
                                Text("Connect")
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                        }
                    }
                }
            }
            .sheet(isPresented: $showWalletConnection) {
                WalletWebViewSheet(isPresented: $showWalletConnection)
            }
        }
        .task {
            await loadData()
        }
    }

    private var readOnlyBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "eye")
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("View Only Mode")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("Connect wallet to vote on proposals")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Connect") {
                showWalletConnection = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var totalBalanceCard: some View {
        VStack(spacing: 8) {
            Text("Total Balance")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(viewModel.formattedTotalBalance)
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.primary)

            if viewModel.assets.count > 0 {
                Text("\(viewModel.assets.count) assets")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private func loadData() async {
        await viewModel.loadDashboard(
            treasuryId: treasury.daoId,
            apiClient: apiClient
        )
    }
}

#Preview {
    DashboardView(
        treasury: Treasury(daoId: "test.sputnik-dao.near", config: nil),
        onBack: {}
    )
    .environment(TreasuryAPIClient.shared)
    .environment(WalletManager.shared)
}
