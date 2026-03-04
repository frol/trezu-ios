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
    @State private var showSearch = false
    @State private var selectedProposal: Proposal?
    /// Tracks whether we need to reload on next appearance (e.g. returning from detail).
    @State private var needsRefresh = false

    private var hasMore: Bool { proposals.count < totalProposals }

    private var effectiveStatuses: [String] {
        selectedTab.statuses
    }

    private var loadTrigger: String {
        "\(selectedTab)-\(searchText)"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented control
                Picker("", selection: $selectedTab) {
                    Text("Pending").tag(RequestsTab.pending)
                    Text("History").tag(RequestsTab.history)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                // History sub-filter
                if selectedTab == .history {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(RequestsTab.historyCases, id: \.self) { tab in
                                FilterChip(
                                    title: tab.displayName,
                                    isSelected: selectedTab == tab
                                ) {
                                    selectedTab = tab
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                }

                // Proposals list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if isLoading && proposals.isEmpty {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.top, 64)
                        } else if proposals.isEmpty {
                            ContentUnavailableView(
                                "No Requests",
                                systemImage: "doc.text",
                                description: Text("No \(selectedTab.displayName.lowercased()) requests.")
                            )
                            .padding(.top, 32)
                        } else {
                            ForEach(proposals) { proposal in
                                ProposalCard(proposal: proposal) {
                                    selectedProposal = proposal
                                }
                                .onAppear {
                                    if proposal == proposals.last, hasMore, !isLoadingMore {
                                        Task { await loadNextPage() }
                                    }
                                }
                            }

                            if isLoadingMore {
                                ProgressView()
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }
                .refreshable {
                    await reload()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Requests")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSearch.toggle()
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
            .sheet(item: $selectedProposal) { proposal in
                ProposalDetailView(proposalId: proposal.id)
            }
            .searchable(text: $searchText, isPresented: $showSearch, prompt: "Search requests")
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
    case pending
    case history       // All non-pending
    case executed
    case rejected
    case expired
    case failed

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .history: return "History"
        case .executed: return "Executed"
        case .rejected: return "Rejected"
        case .expired: return "Expired"
        case .failed: return "Failed"
        }
    }

    var statuses: [String] {
        switch self {
        case .pending: return [ProposalStatus.inProgress.rawValue]
        case .history: return [
            ProposalStatus.approved.rawValue,
            ProposalStatus.rejected.rawValue,
            ProposalStatus.expired.rawValue,
            ProposalStatus.failed.rawValue
        ]
        case .executed: return [ProposalStatus.approved.rawValue]
        case .rejected: return [ProposalStatus.rejected.rawValue]
        case .expired: return [ProposalStatus.expired.rawValue]
        case .failed: return [ProposalStatus.failed.rawValue]
        }
    }

    /// Cases shown as sub-filter chips under History
    static let historyCases: [RequestsTab] = [.history, .executed, .rejected, .expired, .failed]
}

// MARK: - Filter Chip

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
                        .fill(isSelected ? Color.primary : Color(.tertiarySystemFill))
                )
                .foregroundStyle(isSelected ? Color(.systemBackground) : .primary)
        }
    }
}

// MARK: - Proposal Card

struct ProposalCard: View {
    let proposal: Proposal
    let onTap: () -> Void

    @Environment(TreasuryService.self) private var treasuryService
    @Environment(AuthService.self) private var authService

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Top content
                VStack(alignment: .leading, spacing: 6) {
                    // Title row
                    HStack {
                        Text(proposal.displayKind == "Transfer" ? "Payment Request" : proposal.displayKind)
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }

                    // Amount / details line
                    proposalAmountLine

                    // Subtitle: recipient + date
                    proposalSubtitleLine
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)

                // Divider
                Rectangle()
                    .fill(Color(.separator).opacity(0.3))
                    .frame(height: 1)
                    .padding(.horizontal, 16)

                // Bottom: voting indicator
                votingRow
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Amount Line

    @ViewBuilder
    private var proposalAmountLine: some View {
        if proposal.isExchange, let exchange = proposal.exchangeData {
            // Exchange: show from → to
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    SmallTokenIcon(symbol: exchange.tokenDisplayName(exchange.tokenIn))
                    Text(exchange.amountIn)
                        .font(.body.weight(.semibold))
                    Text(exchange.tokenDisplayName(exchange.tokenIn))
                        .font(.body)
                }

                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                }

                HStack(spacing: 4) {
                    SmallTokenIcon(symbol: exchange.tokenDisplayName(exchange.tokenOut))
                    Text(exchange.amountOut)
                        .font(.body.weight(.semibold))
                    Text(exchange.tokenDisplayName(exchange.tokenOut))
                        .font(.body)
                }
            }
        } else if case .transfer(let action) = proposal.kind {
            HStack(spacing: 4) {
                SmallTokenIcon(symbol: tokenSymbolForTransfer(action))
                Text(formattedTransferAmount(action))
                    .font(.body.weight(.semibold))
                Text(tokenSymbolForTransfer(action))
                    .font(.body)
            }
        } else if case .functionCall(let action) = proposal.kind {
            // For function calls, show the contract
            HStack(spacing: 4) {
                Image(systemName: "terminal")
                    .foregroundStyle(.secondary)
                Text(action.receiverId)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        } else {
            // Generic: show kind description
            Text(proposal.decodedDescription.title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    // MARK: - Subtitle

    @ViewBuilder
    private var proposalSubtitleLine: some View {
        HStack(spacing: 4) {
            if case .transfer(let action) = proposal.kind {
                Text("To: \(action.receiverId)")
                    .lineLimit(1)
            }

            if let date = proposal.submissionDate {
                if case .transfer = proposal.kind {
                    Text("·")
                }
                Text(formattedDate(date))
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - Voting Row

    @ViewBuilder
    private var votingRow: some View {
        let approvals = proposal.approvalCount
        let policy = treasuryService.policy
        let accountId = authService.currentUser?.accountId ?? ""

        HStack {
            Text("Voting")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            // Vote count
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.green)

                if proposal.status.isPending, let policy {
                    let required = policy.requiredVotes(for: proposal.kind, accountId: accountId)
                    Text("\(approvals)/\(required)")
                        .font(.subheadline.weight(.medium))
                } else {
                    Text("\(approvals)")
                        .font(.subheadline.weight(.medium))
                }
            }

            // Compact voter avatars
            if let votes = proposal.votes, !votes.isEmpty {
                CompactVoterAvatars(votes: votes)
            }
        }
    }

    // MARK: - Helpers

    private func tokenSymbolForTransfer(_ action: TransferAction) -> String {
        if let tokenId = action.tokenId, !tokenId.isEmpty {
            return tokenDisplayName(tokenId)
        }
        return "NEAR"
    }

    private func tokenDisplayName(_ token: String) -> String {
        let known: [String: String] = [
            "near": "NEAR",
            "wrap.near": "wNEAR",
            "usdt.tether-token.near": "USDt",
        ]
        if let name = known[token.lowercased()] { return name }
        if token.hasSuffix(".near") { return token }
        if token.count > 20 { return "\(token.prefix(6))…\(token.suffix(4))" }
        return token
    }

    private func formattedTransferAmount(_ action: TransferAction) -> String {
        if let tokenId = action.tokenId, !tokenId.isEmpty {
            // For FT tokens, the amount is already in smallest units
            // We need the decimals from the assets list
            return action.amount
        }
        return formatNEAR(action.amount)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy h:mm a"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date) + " UTC"
    }
}

// MARK: - Small Token Icon

struct SmallTokenIcon: View {
    let symbol: String

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.15))
            Text(String(symbol.prefix(1)))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.tint)
        }
        .frame(width: 20, height: 20)
        .clipShape(Circle())
    }
}

// MARK: - Compact Voter Avatars

struct CompactVoterAvatars: View {
    let votes: [String: String]

    var body: some View {
        HStack(spacing: -6) {
            ForEach(Array(votes.keys.sorted().prefix(3)), id: \.self) { accountId in
                let vote = Vote(rawValue: votes[accountId] ?? "")
                VoterAvatar(accountId: accountId, vote: vote)
            }
            if votes.count > 3 {
                Text("+\(votes.count - 3)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 8)
            }
        }
    }
}

struct VoterAvatar: View {
    let accountId: String
    let vote: Vote?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Avatar circle with initial
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 28, height: 28)
                .overlay {
                    Text(String(accountId.prefix(1)).uppercased())
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

            // Vote badge
            if let vote {
                Circle()
                    .fill(vote == .approve ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                    .overlay {
                        Image(systemName: vote == .approve ? "checkmark" : "xmark")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .offset(x: -2, y: 2)
            }
        }
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

    var icon: String {
        switch status {
        case .approved: return "checkmark.circle.fill"
        case .rejected: return "xmark.circle.fill"
        case .inProgress: return "clock.fill"
        case .expired: return "clock.badge.exclamationmark.fill"
        case .removed: return "trash.circle.fill"
        case .moved: return "arrow.right.circle.fill"
        case .failed: return "exclamationmark.circle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(status.displayName)
        }
        .font(.subheadline.weight(.semibold))
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
