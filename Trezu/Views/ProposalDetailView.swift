import SwiftUI
import NEARConnect

struct ProposalDetailView: View {
    let proposalId: Int

    @Environment(TreasuryService.self) private var treasuryService
    @Environment(AuthService.self) private var authService
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var walletManager: NEARWalletManager

    @State private var proposal: Proposal?
    @State private var isLoading = true
    @State private var error: String?
    @State private var showVoteConfirmation = false
    @State private var pendingVote: Vote?
    @State private var isVoting = false
    @State private var voteError: String?
    @State private var voteSuccess: Vote?

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
                    VStack(spacing: 0) {
                        // Success banner
                        if let vote = voteSuccess {
                            voteSuccessBanner(vote)
                                .padding(.horizontal)
                                .padding(.bottom, 12)
                        }

                        // Hero section: icon + amount + date
                        heroSection(proposal)

                        // Status badge
                        statusRow(proposal)
                            .padding(.top, 16)
                            .padding(.horizontal)

                        // Info rows
                        VStack(spacing: 0) {
                            infoRows(proposal)
                            votingInfoRow(proposal)
                            executedDateRow(proposal)
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)

                        // Vote actions for pending proposals
                        if proposal.status.isPending {
                            voteActionsSection(proposal)
                                .padding(.horizontal)
                                .padding(.top, 16)
                        }

                        // View Transaction button
                        viewTransactionButton(proposal)
                            .padding(.horizontal)
                            .padding(.top, 24)
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
        let kindName = proposal.displayKind == "Transfer" ? "Payment Request" : proposal.displayKind
        return "\(kindName) #\(proposal.id)"
    }

    // MARK: - Hero Section

    @ViewBuilder
    private func heroSection(_ proposal: Proposal) -> some View {
        VStack(spacing: 8) {
            if proposal.isExchange, let exchange = proposal.exchangeData {
                // Exchange hero
                HStack(spacing: -8) {
                    TokenIconView(icon: nil, symbol: exchange.tokenDisplayName(exchange.tokenIn))
                        .frame(width: 44, height: 44)
                    TokenIconView(icon: nil, symbol: exchange.tokenDisplayName(exchange.tokenOut))
                        .frame(width: 44, height: 44)
                }
                .padding(.top, 16)

                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        Text(exchange.amountIn)
                            .font(.system(size: 32, weight: .bold))
                        Text(exchange.tokenDisplayName(exchange.tokenIn))
                            .font(.system(size: 32, weight: .bold))
                    }
                    Image(systemName: "arrow.down")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Text(exchange.amountOut)
                            .font(.system(size: 32, weight: .bold))
                        Text(exchange.tokenDisplayName(exchange.tokenOut))
                            .font(.system(size: 32, weight: .bold))
                    }
                }
            } else if case .transfer(let action) = proposal.kind {
                // Transfer hero
                let symbol = transferTokenSymbol(action)
                TokenIconView(icon: nil, symbol: symbol)
                    .frame(width: 48, height: 48)
                    .padding(.top, 16)

                HStack(spacing: 6) {
                    Text(transferFormattedAmount(action))
                        .font(.system(size: 32, weight: .bold))
                    Text(symbol)
                        .font(.system(size: 32, weight: .bold))
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
                Text(formattedDateUTC(date))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Status Row

    @ViewBuilder
    private func statusRow(_ proposal: Proposal) -> some View {
        let color = statusColor(proposal.status)
        HStack(spacing: 6) {
            Image(systemName: statusIcon(proposal.status))
            Text(proposal.status.displayName)
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
        // Recipient
        if case .transfer(let action) = proposal.kind {
            DetailRow(label: "Recipient") {
                AccountDisplay(accountId: action.receiverId)
            }

            DashedDivider()
        }

        if case .functionCall(let action) = proposal.kind {
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

        // Exchange extra details
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

        // Requester
        DetailRow(label: "Requester") {
            AccountDisplay(accountId: proposal.proposer)
        }

        DashedDivider()
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
                    Text(formattedDateUTC(date))
                        .font(.subheadline)
                }
            }
        }
    }

    // MARK: - Vote Actions Section

    @ViewBuilder
    private func voteActionsSection(_ proposal: Proposal) -> some View {
        let hasUserVoted = proposal.userVote(accountId: currentAccountId) != nil

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
                        .background(Color.primary, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(Color(.systemBackground))
                    }
                    .disabled(isVoting)
                }

                if isVoting {
                    ProgressView("Submitting vote...")
                }
            }
        }
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

    private func transferTokenSymbol(_ action: TransferAction) -> String {
        if let tokenId = action.tokenId, !tokenId.isEmpty {
            let known: [String: String] = [
                "near": "NEAR", "wrap.near": "wNEAR",
                "usdt.tether-token.near": "USDt",
            ]
            return known[tokenId.lowercased()] ?? tokenId
        }
        return "NEAR"
    }

    private func transferFormattedAmount(_ action: TransferAction) -> String {
        if let tokenId = action.tokenId, !tokenId.isEmpty {
            return action.amount
        }
        return formatNEAR(action.amount)
    }

    private func formattedDateUTC(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy h:mm a"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date) + " UTC"
    }

    // MARK: - Data Loading

    private func loadProposal() async {
        isLoading = true
        error = nil
        do {
            proposal = try await treasuryService.loadProposal(proposalId: proposalId)
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
