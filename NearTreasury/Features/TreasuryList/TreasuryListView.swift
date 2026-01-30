import SwiftUI

struct TreasuryListView: View {
    @Environment(WalletManager.self) private var walletManager
    @Environment(TreasuryAPIClient.self) private var apiClient
    @State private var viewModel = TreasuryListViewModel()

    let onSelectTreasury: (Treasury) -> Void

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .loading:
                    LoadingView(message: "Loading treasuries...")

                case .loaded(let treasuries):
                    if treasuries.isEmpty {
                        EmptyStateView(
                            title: "No Treasuries",
                            description: "You don't have access to any treasuries yet",
                            systemImage: "building.columns"
                        )
                    } else {
                        treasuryList(treasuries)
                    }

                case .error(let error):
                    ErrorView(error: error) {
                        Task {
                            await loadTreasuries()
                        }
                    }
                }
            }
            .navigationTitle("Treasuries")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
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
                }
            }
            .refreshable {
                await loadTreasuries()
            }
        }
        .task {
            await loadTreasuries()
        }
    }

    @ViewBuilder
    private func treasuryList(_ treasuries: [Treasury]) -> some View {
        List(treasuries) { treasury in
            TreasuryRowView(treasury: treasury)
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelectTreasury(treasury)
                }
        }
        .listStyle(.insetGrouped)
    }

    private func loadTreasuries() async {
        guard let accountId = walletManager.currentAccountId else { return }
        await viewModel.loadTreasuries(accountId: accountId, apiClient: apiClient)
    }
}

struct TreasuryRowView: View {
    let treasury: Treasury

    var body: some View {
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
        .padding(.vertical, 4)
    }

    private var treasuryColor: Color {
        let colors: [Color] = [.blue, .purple, .orange, .green, .pink, .teal, .indigo]
        let index = abs(treasury.daoId.hashValue) % colors.count
        return colors[index]
    }
}

#Preview {
    TreasuryListView(onSelectTreasury: { _ in })
        .environment(WalletManager.shared)
        .environment(TreasuryAPIClient.shared)
}
