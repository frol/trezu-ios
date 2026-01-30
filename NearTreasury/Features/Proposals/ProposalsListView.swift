import SwiftUI

struct ProposalsListView: View {
    @Environment(TreasuryAPIClient.self) private var apiClient
    @Environment(WalletManager.self) private var walletManager
    @State private var viewModel = ProposalsListViewModel()
    @State private var selectedProposal: Proposal?

    let treasury: Treasury

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter tabs
                filterTabs

                Divider()

                // Content
                Group {
                    switch viewModel.state {
                    case .loading:
                        LoadingView(message: "Loading proposals...")

                    case .loaded:
                        if viewModel.filteredProposals.isEmpty {
                            emptyState
                        } else {
                            proposalsList
                        }

                    case .error(let error):
                        ErrorView(error: error) {
                            Task {
                                await loadProposals()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Proposals")
            .navigationDestination(item: $selectedProposal) { proposal in
                ProposalDetailView(
                    treasury: treasury,
                    proposal: proposal,
                    onVoteSubmitted: {
                        Task {
                            await loadProposals()
                        }
                    }
                )
            }
            .refreshable {
                await loadProposals()
            }
        }
        .task {
            await loadProposals()
        }
    }

    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ProposalsListViewModel.Filter.allCases, id: \.self) { filter in
                    FilterChip(
                        title: filter.title,
                        isSelected: viewModel.selectedFilter == filter,
                        count: viewModel.countForFilter(filter)
                    ) {
                        viewModel.selectedFilter = filter
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }

    private var proposalsList: some View {
        List {
            ForEach(viewModel.filteredProposals) { proposal in
                ProposalRowView(
                    proposal: proposal,
                    currentAccountId: walletManager.currentAccountId
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedProposal = proposal
                }
            }
        }
        .listStyle(.plain)
    }

    private var emptyState: some View {
        EmptyStateView(
            title: "No Proposals",
            description: emptyStateDescription,
            systemImage: "doc.text"
        )
    }

    private var emptyStateDescription: String {
        switch viewModel.selectedFilter {
        case .all:
            return "There are no proposals yet"
        case .pending:
            return "There are no pending proposals"
        case .approved:
            return "There are no approved proposals"
        case .rejected:
            return "There are no rejected proposals"
        case .expired:
            return "There are no expired proposals"
        }
    }

    private func loadProposals() async {
        await viewModel.loadProposals(daoId: treasury.daoId, apiClient: apiClient)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)

                if count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            isSelected ? Color.white.opacity(0.2) : Color.gray.opacity(0.2)
                        )
                        .clipShape(Capsule())
                }
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ProposalsListView(treasury: Treasury(daoId: "test.sputnik-dao.near", config: nil))
        .environment(TreasuryAPIClient.shared)
        .environment(WalletManager.shared)
}
