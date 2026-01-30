import SwiftUI

struct HomeView: View {
    @Environment(WalletManager.self) private var walletManager
    @Environment(TreasuryAPIClient.self) private var apiClient
    @State private var viewModel = HomeViewModel()
    @State private var showWalletConnection = false

    let onSelectTreasury: (Treasury) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Search bar
                    TreasurySearchBar(
                        text: $viewModel.searchQuery,
                        onSubmit: {
                            Task {
                                await viewModel.searchTreasury(apiClient: apiClient)
                            }
                        },
                        isSearching: viewModel.isSearching
                    )

                    // Search error
                    if let error = viewModel.searchError {
                        searchErrorView(error)
                    }

                    // Search result
                    if let treasury = viewModel.searchResult {
                        searchResultView(treasury)
                    }

                    // Recent Treasuries section
                    if !viewModel.recentTreasuries.isEmpty && viewModel.searchResult == nil {
                        recentTreasuriesSection
                    }

                    // My Treasuries section (only when connected)
                    if walletManager.isConnected {
                        myTreasuriesSection
                    }

                    // Empty state when no recent treasuries and no search
                    if viewModel.recentTreasuries.isEmpty && !walletManager.isConnected && viewModel.searchResult == nil {
                        welcomeSection
                    }
                }
                .padding()
            }
            .navigationTitle("Treasury")
            .toolbar {
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
                                    viewModel.clearMyTreasuries()
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
            .onChange(of: walletManager.isConnected) { _, isConnected in
                if isConnected, let accountId = walletManager.currentAccountId {
                    Task {
                        await viewModel.loadMyTreasuries(accountId: accountId, apiClient: apiClient)
                    }
                }
            }
            .task {
                // Load my treasuries if already connected
                if let accountId = walletManager.currentAccountId {
                    await viewModel.loadMyTreasuries(accountId: accountId, apiClient: apiClient)
                }
            }
        }
    }

    // MARK: - Search Error View

    private func searchErrorView(_ error: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)

            Text(error)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Dismiss") {
                viewModel.searchError = nil
            }
            .font(.caption)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Search Result View

    private func searchResultView(_ treasury: Treasury) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Search Result")
                    .font(.headline)

                Spacer()

                Button("Clear") {
                    viewModel.clearSearch()
                }
                .font(.caption)
            }

            TreasuryCard(treasury: treasury) {
                onSelectTreasury(treasury)
            }
        }
    }

    // MARK: - Recent Treasuries Section

    private var recentTreasuriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent")
                    .font(.headline)

                Spacer()

                if viewModel.recentTreasuries.count > 1 {
                    Button("Clear All") {
                        viewModel.clearRecentTreasuries()
                    }
                    .font(.caption)
                }
            }

            LazyVStack(spacing: 8) {
                ForEach(viewModel.recentTreasuries) { summary in
                    RecentTreasuryRow(summary: summary) {
                        // Create treasury from summary and navigate
                        let treasury = Treasury(daoId: summary.daoId, config: nil)
                        viewModel.addToRecentTreasuries(treasury)
                        onSelectTreasury(treasury)
                    } onRemove: {
                        viewModel.removeFromRecentTreasuries(summary.daoId)
                    }
                }
            }
        }
    }

    // MARK: - My Treasuries Section

    private var myTreasuriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("My Treasuries")
                    .font(.headline)

                Spacer()

                if viewModel.isLoadingMyTreasuries {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if viewModel.myTreasuries.isEmpty && !viewModel.isLoadingMyTreasuries {
                EmptyMyTreasuriesView()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.myTreasuries) { treasury in
                        TreasuryCard(treasury: treasury) {
                            viewModel.addToRecentTreasuries(treasury)
                            onSelectTreasury(treasury)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Welcome Section

    private var welcomeSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "building.columns.fill")
                .font(.system(size: 56))
                .foregroundStyle(.blue.gradient)

            Text("Welcome to NEAR Treasury")
                .font(.title2)
                .fontWeight(.bold)

            Text("Search for any treasury by its account ID to view assets, proposals, and members.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Divider()
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 8) {
                Text("Try searching:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(sampleTreasuries, id: \.self) { treasury in
                    Button {
                        viewModel.searchQuery = treasury
                        Task {
                            await viewModel.searchTreasury(apiClient: apiClient)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .font(.caption)
                            Text(treasury)
                                .font(.subheadline)
                        }
                        .foregroundStyle(.blue)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private var sampleTreasuries: [String] {
        [
            "testing-astradao.sputnik-dao.near",
            "devhub.sputnik-dao.near"
        ]
    }
}

// MARK: - Treasury Card

struct TreasuryCard: View {
    let treasury: Treasury
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Treasury icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(treasuryColor.gradient)
                        .frame(width: 48, height: 48)

                    if let logoURL = treasury.config?.metadata?.flagLogo,
                       let url = URL(string: logoURL) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 32, height: 32)
                        } placeholder: {
                            Image(systemName: "building.columns.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                        }
                    } else {
                        Image(systemName: "building.columns.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                }

                // Treasury info
                VStack(alignment: .leading, spacing: 4) {
                    Text(treasury.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(treasury.daoId)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let purpose = treasury.config?.purpose, !purpose.isEmpty {
                        Text(purpose)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 4, y: 1)
        }
        .buttonStyle(.plain)
    }

    private var treasuryColor: Color {
        let colors: [Color] = [.blue, .purple, .orange, .green, .pink, .teal, .indigo]
        let index = abs(treasury.daoId.hashValue) % colors.count
        return colors[index]
    }
}

// MARK: - Recent Treasury Row

struct RecentTreasuryRow: View {
    let summary: TreasurySummary
    let onTap: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(treasuryColor.gradient)
                            .frame(width: 40, height: 40)

                        Image(systemName: "building.columns.fill")
                            .font(.callout)
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(summary.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)

                        Text(summary.daoId)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(summary.formattedLastAccessed)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
    }

    private var treasuryColor: Color {
        let colors: [Color] = [.blue, .purple, .orange, .green, .pink, .teal, .indigo]
        let index = abs(summary.daoId.hashValue) % colors.count
        return colors[index]
    }
}

// MARK: - Empty My Treasuries View

struct EmptyMyTreasuriesView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("No treasuries found")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    HomeView(onSelectTreasury: { _ in })
        .environment(WalletManager.shared)
        .environment(TreasuryAPIClient.shared)
}
