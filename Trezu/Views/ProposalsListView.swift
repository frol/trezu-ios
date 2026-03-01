import SwiftUI
import NEARConnect

struct ProposalsListView: View {
    @Environment(TreasuryService.self) private var treasuryService
    @EnvironmentObject private var walletManager: NEARWalletManager

    @State private var proposals: [Proposal] = []
    @State private var totalProposals = 0
    @State private var currentPage = 0
    @State private var selectedTab: RequestsTab = .pending
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var error: String?
    @State private var showCreateRequest = false
    /// Tracks whether we need to reload on next appearance (e.g. returning from detail).
    @State private var needsRefresh = false

    private var hasMore: Bool { proposals.count < totalProposals }

    /// The status filters sent to the API based on the selected tab.
    private var effectiveStatuses: [String] {
        selectedTab.statuses
    }

    /// A value that changes whenever the query parameters change,
    /// used as the id for `.task(id:)` to cancel stale loads and start fresh.
    private var loadTrigger: String {
        "\(selectedTab)-\(searchText)"
    }

    var body: some View {
        NavigationStack {
            List {
                // Status filter tabs as a list row (no insets)
                Section {
                    StatusFilterBar(selectedTab: $selectedTab)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color(.systemGroupedBackground))
                }

                if isLoading && proposals.isEmpty {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.vertical, 32)
                    }
                } else if proposals.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No Requests",
                            systemImage: "doc.text",
                            description: Text("No \(selectedTab.displayName.lowercased()) requests.")
                        )
                    }
                } else {
                    Section {
                        ForEach(proposals) { proposal in
                            NavigationLink(value: proposal) {
                                ProposalRow(proposal: proposal)
                            }
                            .onAppear {
                                // Infinite scroll: load next page when nearing the end
                                if proposal == proposals.last, hasMore, !isLoadingMore {
                                    Task { await loadNextPage() }
                                }
                            }
                        }
                    }

                    // Loading indicator at the bottom while fetching more
                    if isLoadingMore {
                        Section {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Requests")
            .navigationDestination(for: Proposal.self) { proposal in
                ProposalDetailView(proposalId: proposal.id)
            }
            .searchable(text: $searchText, prompt: "Search requests")
            .refreshable {
                await reload()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateRequest = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateRequest) {
                CreateRequestView()
            }
            .task(id: loadTrigger) {
                await reload()
            }
            .onAppear {
                if needsRefresh {
                    needsRefresh = false
                    Task { await reload() }
                }
            }
            .onDisappear {
                needsRefresh = true
            }
        }
    }

    // MARK: - Data Loading

    private func reload() async {
        currentPage = 0
        proposals = []
        totalProposals = 0
        isLoading = true
        error = nil

        do {
            let result = try await treasuryService.loadProposals(
                statuses: effectiveStatuses,
                page: 0,
                search: searchText.isEmpty ? nil : searchText
            )
            proposals = result.proposals
            totalProposals = result.total
        } catch is CancellationError {
            return
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func loadNextPage() async {
        isLoadingMore = true
        let nextPage = currentPage + 1

        do {
            let result = try await treasuryService.loadProposals(
                statuses: effectiveStatuses,
                page: nextPage,
                search: searchText.isEmpty ? nil : searchText
            )
            proposals.append(contentsOf: result.proposals)
            totalProposals = result.total
            currentPage = nextPage
        } catch is CancellationError {
            return
        } catch {
            self.error = error.localizedDescription
        }

        isLoadingMore = false
    }
}

// MARK: - Requests Tab

enum RequestsTab: Hashable {
    case all
    case pending
    case executed
    case rejected
    case expired
    case failed

    var displayName: String {
        switch self {
        case .all: return "All"
        case .pending: return "Pending"
        case .executed: return "Executed"
        case .rejected: return "Rejected"
        case .expired: return "Expired"
        case .failed: return "Failed"
        }
    }

    var statuses: [String] {
        switch self {
        case .all: return []
        case .pending: return [ProposalStatus.inProgress.rawValue]
        case .executed: return [ProposalStatus.approved.rawValue]
        case .rejected: return [ProposalStatus.rejected.rawValue]
        case .expired: return [ProposalStatus.expired.rawValue]
        case .failed: return [ProposalStatus.failed.rawValue]
        }
    }
}

// MARK: - Status Filter Bar

struct StatusFilterBar: View {
    @Binding var selectedTab: RequestsTab

    private static let tabs: [RequestsTab] = [.all, .pending, .executed, .rejected, .expired, .failed]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Self.tabs, id: \.self) { tab in
                    FilterChip(title: tab.displayName, isSelected: selectedTab == tab) {
                        selectedTab = tab
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color(.tertiarySystemFill))
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
    }
}

// MARK: - Proposal Row

struct ProposalRow: View {
    let proposal: Proposal

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: proposal.displayIcon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(proposal.decodedDescription.title)
                        .font(.body.weight(.medium))
                        .lineLimit(2)
                    Spacer()
                    ProposalStatusBadge(status: proposal.status)
                }

                // Exchange summary line
                if let exchange = proposal.exchangeData {
                    HStack(spacing: 4) {
                        Text(exchange.amountIn)
                        Text(exchange.tokenDisplayName(exchange.tokenIn))
                            .foregroundStyle(.tint)
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                        Text(exchange.amountOut)
                        Text(exchange.tokenDisplayName(exchange.tokenOut))
                            .foregroundStyle(.tint)
                    }
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                }

                HStack(spacing: 8) {
                    Text("#\(proposal.id)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(proposal.displayKind)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let date = proposal.submissionDate {
                        Text(date, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("by \(proposal.proposer)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Proposal Status Badge

struct ProposalStatusBadge: View {
    let status: ProposalStatus

    var color: Color {
        switch status {
        case .approved: return .green
        case .rejected: return .red
        case .inProgress: return .orange
        case .expired: return .gray
        case .removed: return .gray
        case .moved: return .blue
        case .failed: return .red
        }
    }

    var body: some View {
        Text(status.displayName)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

// Make Proposal conform to Hashable for NavigationLink
extension Proposal: Hashable {
    static func == (lhs: Proposal, rhs: Proposal) -> Bool {
        lhs.id == rhs.id && lhs.daoId == rhs.daoId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(daoId)
    }
}
