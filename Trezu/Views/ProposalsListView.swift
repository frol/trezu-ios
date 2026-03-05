import SwiftUI
import NEARConnect

struct ProposalsListView: View {
    @Environment(TreasuryService.self) private var treasuryService
    @EnvironmentObject private var walletManager: NEARWalletManager

    @State private var proposals: [Proposal] = []
    @State private var totalProposals = 0
    @State private var currentPage = 0
    @State private var selectedTab: RequestsTab = .pending
    @State private var historyFilter: RequestsTab = .history
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
        selectedTab == .history ? historyFilter.statuses : selectedTab.statuses
    }

    private var loadTrigger: String {
        "\(selectedTab)-\(historyFilter)-\(searchText)"
    }

    var body: some View {
        NavigationStack {
            List {
                // Segmented control + history sub-filter
                Section {
                    Picker("", selection: $selectedTab) {
                        Text("Pending").tag(RequestsTab.pending)
                        Text("History").tag(RequestsTab.history)
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                    if selectedTab == .history {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(RequestsTab.historyCases, id: \.self) { filter in
                                    FilterChip(
                                        title: filter.displayName,
                                        isSelected: historyFilter == filter
                                    ) {
                                        historyFilter = filter
                                    }
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                    }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

                // Proposals
                Section {
                    if isLoading && proposals.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 64)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    } else if proposals.isEmpty {
                        ContentUnavailableView(
                            "No Requests",
                            systemImage: "doc.text",
                            description: Text("No \((selectedTab == .history ? historyFilter : selectedTab).displayName.lowercased()) requests.")
                        )
                        .padding(.top, 32)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
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
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        }

                        if isLoadingMore {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Requests")
            .searchable(text: $searchText, isPresented: $showSearch, placement: .toolbar, prompt: "Search requests")
            .refreshable {
                await reload()
            }
            .sheet(item: $selectedProposal) { proposal in
                ProposalDetailView(proposalId: proposal.id)
            }
            .task(id: loadTrigger) {
                await reload(clearList: true)
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

    private func reload(clearList: Bool = false) async {
        currentPage = 0
        if clearList || proposals.isEmpty {
            withAnimation {
                proposals = []
                totalProposals = 0
                isLoading = true
            }
        }
        error = nil

        do {
            let result = try await treasuryService.loadProposals(
                statuses: effectiveStatuses,
                page: 0,
                search: searchText.isEmpty ? nil : searchText
            )
            withAnimation {
                proposals = result.proposals
                totalProposals = result.total
                isLoading = false
            }
        } catch is CancellationError {
            return
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
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
            withAnimation {
                proposals.append(contentsOf: result.proposals)
                totalProposals = result.total
            }
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

    @State private var resolvedData: ResolvedProposalData?
    @State private var batchRecipientCount: Int?
    @State private var exchangeTokenIn: TokenMetadata?
    @State private var exchangeTokenOut: TokenMetadata?

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Top content
                HStack(alignment: .top, spacing: 12) {
                    // Token icon
                    cardTokenIcon
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 6) {
                        // Title row
                        HStack {
                            Text(proposal.displayKind)
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
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .task(id: proposal.id) {
            let resolved = await treasuryService.resolveProposalData(proposal)
            resolvedData = resolved
            // Fetch batch recipient count
            if let batchId = resolved?.batchPaymentId, !batchId.isEmpty {
                let response = await treasuryService.getBatchPayment(batchId: batchId)
                batchRecipientCount = response?.payments?.count
            }
            // Resolve exchange token metadata
            if proposal.isExchange, let exchange = proposal.exchangeData {
                async let tokenInMeta = treasuryService.getTokenMetadata(tokenId: exchange.tokenIn)
                async let tokenOutMeta = treasuryService.getTokenMetadata(tokenId: exchange.tokenOut)
                exchangeTokenIn = await tokenInMeta
                exchangeTokenOut = await tokenOutMeta
            }
        }
    }

    // MARK: - Amount Line

    @ViewBuilder
    private var proposalAmountLine: some View {
        if proposal.isExchange, let exchange = proposal.exchangeData {
            // Exchange: show from → to with resolved token metadata
            let symbolIn = exchangeTokenIn?.symbol ?? exchange.tokenDisplayName(exchange.tokenIn)
            let symbolOut = exchangeTokenOut?.symbol ?? exchange.tokenDisplayName(exchange.tokenOut)

            VStack(alignment: .leading, spacing: 2) {
                exchangeTokenRow(symbol: symbolIn,
                                 amount: exchange.amountIn, price: exchangeTokenIn?.price)

                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                }

                exchangeTokenRow(symbol: symbolOut,
                                 amount: exchange.amountOut, price: exchangeTokenOut?.price)
            }
        } else if let data = resolvedData, !data.amount.isEmpty, data.amount != "0" {
            // Resolved payment data — properly formatted
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(data.formattedAmount)
                        .font(.body.weight(.semibold))
                    Text(data.tokenSymbol)
                        .font(.body)
                }
                if let usd = data.formattedUSD {
                    Text(usd)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } else if proposal.uiKind == .functionCall {
            // Generic function call — show contract
            if case .functionCall(let action) = proposal.kind {
                HStack(spacing: 4) {
                    Image(systemName: "terminal")
                        .foregroundStyle(.secondary)
                    Text(action.receiverId)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        } else {
            // Fallback: show description title
            Text(proposal.decodedDescription.title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private func exchangeTokenRow(symbol: String, amount: String, price: Double?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(formatDecimalAmount(amount, tokenPrice: price))
                    .font(.body.weight(.semibold))
                Text(symbol)
                    .font(.body)
            }
            if let price, price > 0, let amountVal = Double(amount) {
                Text(formatCurrency(amountVal * price))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Card Token Icon

    @ViewBuilder
    private var cardTokenIcon: some View {
        if proposal.isExchange {
            // Overlapping exchange token icons
            ZStack(alignment: .bottomTrailing) {
                TokenIconView(icon: exchangeTokenIn?.icon, symbol: exchangeTokenIn?.symbol ?? "?")
                    .frame(width: 36, height: 36)
                TokenIconView(icon: exchangeTokenOut?.icon, symbol: exchangeTokenOut?.symbol ?? "?")
                    .frame(width: 22, height: 22)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color(.secondarySystemGroupedBackground), lineWidth: 2))
                    .offset(x: 4, y: 4)
            }
            .frame(width: 40, height: 40)
        } else if let data = resolvedData, data.tokenIcon != nil || !data.tokenSymbol.isEmpty {
            // Payment / batch payment token icon
            TokenIconView(icon: data.tokenIcon, symbol: data.tokenSymbol)
                .frame(width: 36, height: 36)
        } else {
            // Generic proposal icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                Image(systemName: proposal.displayIcon)
                    .font(.system(size: 16))
                    .foregroundStyle(.tint)
            }
            .frame(width: 36, height: 36)
        }
    }

    // MARK: - Subtitle

    @ViewBuilder
    private var proposalSubtitleLine: some View {
        HStack(spacing: 4) {
            if proposal.uiKind == .batchPaymentRequest {
                if let count = batchRecipientCount {
                    Text("\(count) recipient\(count == 1 ? "" : "s")")
                        .lineLimit(1)
                } else {
                    Text("Batch payment")
                        .lineLimit(1)
                }
            } else if proposal.uiKind == .exchange {
                // No recipient for exchanges
            } else if let data = resolvedData, !data.receiver.isEmpty,
                      data.receiver != bulkPaymentContractId {
                Text("To: \(data.receiver)")
                    .lineLimit(1)
            }

            if let date = proposal.submissionDate {
                let showDot = proposal.uiKind != .exchange &&
                    (proposal.uiKind == .batchPaymentRequest || (resolvedData?.receiver.isEmpty == false && resolvedData?.receiver != bulkPaymentContractId))
                if showDot {
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

    private func formattedDate(_ date: Date) -> String {
        let interval = Date.now.timeIntervalSince(date)
        // Use relative format for dates within the last 7 days
        if interval > 0 && interval < 7 * 24 * 3600 {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            return formatter.localizedString(for: date, relativeTo: .now)
        }
        return date.formatted(.dateTime.month(.abbreviated).day().year())
    }
}

// MARK: - Small Token Icon

struct SmallTokenIcon: View {
    let symbol: String
    let iconURL: String?

    var body: some View {
        if let iconURL, let url = URL(string: iconURL) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                fallbackIcon
            }
            .frame(width: 20, height: 20)
            .clipShape(Circle())
        } else {
            fallbackIcon
        }
    }

    private var fallbackIcon: some View {
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
