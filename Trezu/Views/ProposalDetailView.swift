import SwiftUI
import NEARConnect

struct ProposalDetailView: View {
    let proposalId: Int

    @Environment(TreasuryService.self) private var treasuryService
    @Environment(AuthService.self) private var authService
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var walletManager: NEARWalletManager

    @State private var proposal: Proposal?
    @State private var resolvedData: ResolvedProposalData?
    @State private var batchPayments: [BatchPayment]?
    @State private var exchangeTokenIn: TokenMetadata?
    @State private var exchangeTokenOut: TokenMetadata?
    @State private var isLoading = true
    @State private var error: String?
    @State private var showVoteConfirmation = false
    @State private var pendingVote: Vote?
    @State private var isVoting = false
    @State private var voteError: String?
    @State private var voteSuccess: Vote?
    @State private var showUTC = false
    @State private var insufficientBalanceWarning: String?

    private var currentAccountId: String {
        authService.currentUser?.accountId ?? ""
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 64)
                } else if let proposal {
                    VStack(spacing: 12) {
                        // Success banner
                        if let vote = voteSuccess {
                            voteSuccessBanner(vote)
                                .padding(.horizontal)
                        }

                        // Hero card: icon + amount + date + status
                        VStack(spacing: 0) {
                            heroSection(proposal)
                            statusRow(proposal)
                                .padding(.top, 16)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 16)
                        }
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)

                        // Info card: detail rows + voting
                        VStack(spacing: 0) {
                            infoRows(proposal)
                            votingInfoRow(proposal)
                            executedDateRow(proposal)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)

                        // Vote actions for pending proposals (with client-side expiration check)
                        if proposal.effectiveStatus(proposalPeriod: treasuryService.policy?.proposalPeriod).isPending {
                            voteActionsSection(proposal)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                                .padding(.horizontal)
                        } else if proposal.status.isPending {
                            // Server still says InProgress but client detected expiration
                            expiredBanner
                                .padding(.horizontal)
                        }

                        // View Transaction button
                        viewTransactionButton(proposal)
                            .padding(.horizontal)
                            .padding(.top, 8)
                            .padding(.bottom, 32)
                    }
                } else if let error {
                    ContentUnavailableView(
                        "Error",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(detailTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("", systemImage: "xmark.circle.fill") {
                        dismiss()
                    }
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .task { await loadProposal() }
        .interactiveDismissDisabled(isVoting)
        .alert("Confirm Vote", isPresented: $showVoteConfirmation, presenting: pendingVote) { vote in
            Button("Cancel", role: .cancel) { }
            Button(vote.rawValue, role: vote == .reject ? .destructive : nil) {
                Task { await submitVote(vote) }
            }
        } message: { vote in
            Text("Are you sure you want to \(vote.rawValue.lowercased()) this request?")
        }
    }

    private var detailTitle: String {
        guard let proposal else { return "Request #\(proposalId)" }
        return "\(proposal.displayKind) #\(proposal.id)"
    }

    // MARK: - Hero Section

    @ViewBuilder
    private func heroSection(_ proposal: Proposal) -> some View {
        VStack(spacing: 8) {
            if proposal.isExchange, let exchange = proposal.exchangeData {
                // Exchange hero
                let symbolIn = exchangeTokenIn?.symbol ?? exchange.tokenDisplayName(exchange.tokenIn)
                let symbolOut = exchangeTokenOut?.symbol ?? exchange.tokenDisplayName(exchange.tokenOut)

                HStack(spacing: -8) {
                    TokenIconWithNetwork(
                        icon: exchangeTokenIn?.icon,
                        symbol: symbolIn,
                        chainIcon: exchangeTokenIn?.chainIcons?.light
                    )
                    TokenIconWithNetwork(
                        icon: exchangeTokenOut?.icon,
                        symbol: symbolOut,
                        chainIcon: exchangeTokenOut?.chainIcons?.light
                    )
                }
                .padding(.top, 16)

                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        Text(formatDecimalAmount(exchange.amountIn, tokenPrice: exchangeTokenIn?.price))
                            .font(.system(size: 32, weight: .bold))
                        Text(symbolIn)
                            .font(.system(size: 32, weight: .bold))
                    }

                    // USD value for input
                    if let price = exchangeTokenIn?.price, price > 0,
                       let inVal = Double(exchange.amountIn) {
                        Text(formatCurrency(inVal * price))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Image(systemName: "arrow.down")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        Text(formatDecimalAmount(exchange.amountOut, tokenPrice: exchangeTokenOut?.price))
                            .font(.system(size: 32, weight: .bold))
                        Text(symbolOut)
                            .font(.system(size: 32, weight: .bold))
                    }

                    // USD value for output
                    if let price = exchangeTokenOut?.price, price > 0,
                       let outVal = Double(exchange.amountOut) {
                        Text(formatCurrency(outVal * price))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if let data = resolvedData, !data.amount.isEmpty, data.amount != "0" {
                // Payment/transfer/staking hero with resolved metadata
                TokenIconWithNetwork(icon: data.tokenIcon, symbol: data.tokenSymbol, chainIcon: data.tokenChainIcon)
                    .padding(.top, 16)

                HStack(spacing: 6) {
                    Text(data.formattedAmount)
                        .font(.system(size: 32, weight: .bold))
                    Text(data.tokenSymbol)
                        .font(.system(size: 32, weight: .bold))
                }

                if let usd = data.formattedUSD {
                    Text(usd)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                // Generic hero
                Image(systemName: proposal.displayIcon)
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                    .padding(.top, 16)

                Text(proposal.decodedDescription.title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Date
            if let date = proposal.submissionDate {
                Text(formattedDateLocal(date))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
                    .onTapGesture { showUTC.toggle() }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Status Row

    @ViewBuilder
    private func statusRow(_ proposal: Proposal) -> some View {
        let effective = proposal.effectiveStatus(proposalPeriod: treasuryService.policy?.proposalPeriod)
        let color = statusColor(effective)
        HStack(spacing: 6) {
            Image(systemName: statusIcon(effective))
            Text(effective.displayName)
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Info Rows

    @ViewBuilder
    private func infoRows(_ proposal: Proposal) -> some View {
        let uiKind = proposal.uiKind

        // Recipient — skip for exchanges and batch payments
        if uiKind != .exchange && uiKind != .batchPaymentRequest {
            if let data = resolvedData, !data.receiver.isEmpty,
               data.receiver != bulkPaymentContractId {
                DetailRow(label: "Recipient") {
                    AccountDisplay(accountId: data.receiver)
                }
                DashedDivider()
            } else if case .transfer(let action) = proposal.kind, resolvedData == nil {
                DetailRow(label: "Recipient") {
                    AccountDisplay(accountId: action.receiverId)
                }
                DashedDivider()
            }
        }

        if case .functionCall(let action) = proposal.kind {
            if uiKind == .functionCall {
                DetailRow(label: "Contract") {
                    AccountDisplay(accountId: action.receiverId)
                }
                if let first = action.actions.first {
                    DashedDivider()
                    DetailRow(label: "Method") {
                        Text(first.methodName)
                            .font(.subheadline)
                    }
                }
                DashedDivider()
            } else if uiKind == .earnNEAR || uiKind == .unstakeNEAR || uiKind == .withdrawEarnings {
                DetailRow(label: "Validator") {
                    AccountDisplay(accountId: action.receiverId)
                }
                DashedDivider()
            }
        }

        if case .addMemberToRole(let action) = proposal.kind {
            DetailRow(label: "Account") {
                AccountDisplay(accountId: action.memberId)
            }
            DashedDivider()
            DetailRow(label: "Role") {
                Text(action.role)
                    .font(.subheadline)
            }
            DashedDivider()
        }

        if case .removeMemberFromRole(let action) = proposal.kind {
            DetailRow(label: "Account") {
                AccountDisplay(accountId: action.memberId)
            }
            DashedDivider()
            DetailRow(label: "Role") {
                Text(action.role)
                    .font(.subheadline)
            }
            DashedDivider()
        }

        // Exchange extra details — no recipient, show slippage/deposit
        if let exchange = proposal.exchangeData {
            if let slippage = exchange.slippage {
                DetailRow(label: "Slippage") {
                    Text("\(slippage)%").font(.subheadline)
                }
                DashedDivider()
            }
            if let depositAddress = exchange.depositAddress {
                DetailRow(label: "Deposit Address") {
                    Text(depositAddress)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                DashedDivider()
            }
        }

        // Batch payment recipients
        if uiKind == .batchPaymentRequest {
            batchPaymentRecipientsSection
            DashedDivider()
        }

        // Requester
        DetailRow(label: "Requester") {
            AccountDisplay(accountId: proposal.proposer)
        }

        DashedDivider()
    }

    // MARK: - Batch Payment Recipients

    @ViewBuilder
    private var batchPaymentRecipientsSection: some View {
        if let payments = batchPayments, !payments.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Recipients (\(payments.count))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)

                ForEach(Array(payments.enumerated()), id: \.element.id) { index, payment in
                    HStack {
                        HStack(spacing: 6) {
                            Text("\(index + 1).")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .frame(width: 24, alignment: .leading)
                            Text(payment.recipient)
                                .font(.subheadline)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        if let data = resolvedData {
                            Text("\(formatTokenAmount(payment.amount, decimals: data.tokenDecimals, tokenPrice: data.tokenPrice)) \(data.tokenSymbol)")
                                .font(.subheadline.weight(.medium))
                        }
                    }

                    if index < payments.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(.bottom, 12)
        } else if resolvedData?.batchPaymentId != nil {
            HStack {
                Text("Recipients")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                ProgressView()
                    .controlSize(.small)
            }
            .padding(.vertical, 12)
        }
    }

    // MARK: - Voting Info Row

    @ViewBuilder
    private func votingInfoRow(_ proposal: Proposal) -> some View {
        let approvals = proposal.approvalCount
        let policy = treasuryService.policy

        DetailRow(label: "Voting") {
            HStack(spacing: 8) {
                VStack(alignment: .trailing, spacing: 2) {
                    if proposal.status.isPending, let policy {
                        let required = policy.requiredVotes(for: proposal.kind, accountId: currentAccountId)
                        Text("\(approvals)/\(required) approvals received")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(approvals) approvals received")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let votes = proposal.votes, !votes.isEmpty {
                    CompactVoterAvatars(votes: votes)
                }
            }
        }

        DashedDivider()
    }

    // MARK: - Executed Date Row

    @ViewBuilder
    private func executedDateRow(_ proposal: Proposal) -> some View {
        if !proposal.status.isPending {
            DetailRow(label: proposal.status.displayName) {
                if let date = proposal.submissionDate {
                    Text(formattedDateLocal(date))
                        .font(.subheadline)
                        .onTapGesture { showUTC.toggle() }
                }
            }
        }
    }

    // MARK: - Vote Actions Section

    @ViewBuilder
    private func voteActionsSection(_ proposal: Proposal) -> some View {
        let hasUserVoted = proposal.userVote(accountId: currentAccountId) != nil
        let balanceWarning = insufficientBalanceWarning

        if hasUserVoted && voteSuccess == nil {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.secondary)
                Text("You have already voted on this request.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
        } else if !hasUserVoted && voteSuccess == nil {
            VStack(spacing: 12) {
                // Insufficient balance warning
                if let balanceWarning {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(balanceWarning)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                }

                if let voteError {
                    Text(voteError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                HStack(spacing: 12) {
                    Button {
                        pendingVote = .reject
                        showVoteConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "xmark")
                                .font(.body.weight(.semibold))
                            Text("Reject")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.primary)
                    }
                    .disabled(isVoting)

                    Button {
                        pendingVote = .approve
                        showVoteConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "checkmark")
                                .font(.body.weight(.semibold))
                            Text("Approve")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            balanceWarning != nil ? Color(.systemGray4) : Color.primary,
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                        .foregroundStyle(
                            balanceWarning != nil ? .secondary : Color(.systemBackground)
                        )
                    }
                    .disabled(isVoting || balanceWarning != nil)
                }

                if isVoting {
                    ProgressView("Submitting vote...")
                }
            }
        }
    }

    // MARK: - Expired Banner

    private var expiredBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.badge.exclamationmark")
                .foregroundStyle(.orange)
            Text("This request has expired and can no longer be voted on.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Insufficient Balance Check

    /// Fetches the token balance from the API and checks if the treasury has enough funds for this proposal.
    private func checkInsufficientBalance(for proposal: Proposal) async {
        guard let funds = proposal.requiredFunds else {
            insufficientBalanceWarning = nil
            return
        }

        let tokenId = funds.tokenId
        let requiredStr = funds.amount

        guard let required = Decimal(string: requiredStr), required > 0 else {
            insufficientBalanceWarning = nil
            return
        }

        guard let daoId = treasuryService.daoId else {
            insufficientBalanceWarning = nil
            return
        }

        // Fetch token metadata to get the network and symbol/decimals
        let metadataTokenId = (tokenId == "near" || tokenId.isEmpty) ? "near" : tokenId
        guard let metadata = try? await APIClient.shared.getTokenMetadata(tokenId: metadataTokenId) else {
            insufficientBalanceWarning = nil
            return
        }

        let network = metadata.network ?? "near"

        // Fetch the actual balance from the dedicated balance endpoint
        guard let tokenBalance = try? await APIClient.shared.getTokenBalance(
            accountId: daoId,
            tokenId: metadataTokenId,
            network: network
        ) else {
            insufficientBalanceWarning = nil
            return
        }

        let available = Decimal(string: tokenBalance.balance) ?? 0
        guard required > available else {
            insufficientBalanceWarning = nil
            return
        }

        // Calculate the shortfall
        let difference = required - available
        let symbol = metadata.symbol
        let decimals = metadata.decimals
        let formattedDiff = formatTokenAmount("\(difference)", decimals: decimals)

        insufficientBalanceWarning = "This request can't be approved because the treasury has insufficient \(symbol) balance. Add \(formattedDiff) \(symbol) to continue."
    }

    // MARK: - View Transaction Button

    @ViewBuilder
    private func viewTransactionButton(_ proposal: Proposal) -> some View {
        if let daoId = proposal.daoId ?? treasuryService.daoId {
            let urlString = "https://nearblocks.io/txns?query=\(daoId)"
            if let url = URL(string: urlString) {
                Link(destination: url) {
                    HStack {
                        Text("View Transaction")
                            .font(.body.weight(.semibold))
                        Image(systemName: "arrow.up.right")
                            .font(.body.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.primary)
                }
            }
        }
    }

    // MARK: - Vote Success Banner

    @ViewBuilder
    private func voteSuccessBanner(_ vote: Vote) -> some View {
        HStack(spacing: 12) {
            Image(systemName: vote == .approve ? "checkmark.seal.fill" : "xmark.seal.fill")
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("Vote Submitted")
                    .font(.headline)
                Text("You voted to \(vote.rawValue.lowercased()) this request.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(
            (vote == .approve ? Color.green : Color.red).opacity(0.12),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .foregroundStyle(vote == .approve ? .green : .red)
    }

    // MARK: - Helpers

    private func statusColor(_ status: ProposalStatus) -> Color {
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

    private func statusIcon(_ status: ProposalStatus) -> String {
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

    private func formattedDateLocal(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy h:mm a"
        if showUTC {
            formatter.timeZone = TimeZone(identifier: "UTC")
            return formatter.string(from: date) + " UTC"
        } else {
            formatter.timeZone = .current
            let tz = TimeZone.current.abbreviation() ?? ""
            return formatter.string(from: date) + " " + tz
        }
    }

    // MARK: - Data Loading

    private func loadProposal() async {
        isLoading = true
        error = nil
        do {
            let loaded = try await treasuryService.loadProposal(proposalId: proposalId)
            proposal = loaded
            let resolved = await treasuryService.resolveProposalData(loaded)
            resolvedData = resolved

            // Fetch batch payment recipients if applicable
            if let batchId = resolved?.batchPaymentId, !batchId.isEmpty {
                let response = await treasuryService.getBatchPayment(batchId: batchId)
                batchPayments = response?.payments
            }

            // Resolve exchange token metadata for icons and USD
            if loaded.isExchange, let exchange = loaded.exchangeData {
                async let tokenInMeta = treasuryService.getTokenMetadata(tokenId: exchange.tokenIn)
                async let tokenOutMeta = treasuryService.getTokenMetadata(tokenId: exchange.tokenOut)
                exchangeTokenIn = await tokenInMeta
                exchangeTokenOut = await tokenOutMeta
            }

            // Check insufficient balance (fetches from /user/balance API)
            await checkInsufficientBalance(for: loaded)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func submitVote(_ vote: Vote) async {
        guard let proposal else { return }
        isVoting = true
        voteError = nil
        voteSuccess = nil
        do {
            try await treasuryService.voteOnProposal(
                proposalId: proposalId,
                vote: vote,
                rawKind: proposal.rawKind,
                walletManager: walletManager
            )
            withAnimation { voteSuccess = vote }
            await loadProposal()
        } catch {
            voteError = error.localizedDescription
        }
        isVoting = false
    }
}

// MARK: - Detail Row

struct DetailRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            content
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Dashed Divider

struct DashedDivider: View {
    var body: some View {
        Line()
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            .frame(height: 1)
            .foregroundStyle(Color(.separator).opacity(0.4))
    }
}

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return path
    }
}

// MARK: - Token Icon with Network Badge

struct TokenIconWithNetwork: View {
    let icon: String?
    let symbol: String
    let chainIcon: String?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TokenIconView(icon: icon, symbol: symbol)
                .frame(width: 48, height: 48)

            if let chainIcon, let url = URL(string: chainIcon) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    EmptyView()
                }
                .frame(width: 16, height: 16)
                .background(Color(.systemBackground))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1))
                .offset(x: 2, y: 2)
            }
        }
    }
}

// MARK: - Account Display

struct AccountDisplay: View {
    let accountId: String

    var body: some View {
        HStack(spacing: 8) {
            // Avatar
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 32, height: 32)
                .overlay {
                    Text(String(accountId.prefix(1)).uppercased())
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

            VStack(alignment: .trailing, spacing: 1) {
                Text(accountId)
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }
}
