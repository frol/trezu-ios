import SwiftUI
import NEARConnect

struct ProposalDetailView: View {
    let proposalId: Int

    @Environment(TreasuryService.self) private var treasuryService
    @Environment(AuthService.self) private var authService
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
        ScrollView {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 64)
            } else if let proposal {
                VStack(alignment: .leading, spacing: 20) {
                    // Success banner
                    if let vote = voteSuccess {
                        voteSuccessBanner(vote)
                    }

                    // Header
                    proposalHeader(proposal)

                    // Details based on kind
                    proposalKindDetails(proposal)

                    // Voting progress, voters, and actions
                    votingProgressSection(proposal)
                }
                .padding()
            } else if let error {
                ContentUnavailableView(
                    "Error",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            }
        }
        .navigationTitle("Request #\(proposalId)")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadProposal() }
        .refreshable { await loadProposal() }
        .alert("Confirm Vote", isPresented: $showVoteConfirmation, presenting: pendingVote) { vote in
            Button("Cancel", role: .cancel) { }
            Button(vote.rawValue, role: vote == .reject ? .destructive : nil) {
                Task { await submitVote(vote) }
            }
        } message: { vote in
            Text("Are you sure you want to \(vote.rawValue.lowercased()) this request?")
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func proposalHeader(_ proposal: Proposal) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ProposalStatusBadge(status: proposal.status)
                Spacer()
                Text("#\(proposal.id)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(proposal.decodedDescription.title)
                .font(.title3.bold())

            if let notes = proposal.decodedDescription.notes {
                Text(notes)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            if let urlString = proposal.decodedDescription.url,
               let url = URL(string: urlString) {
                Link(destination: url) {
                    Label(urlString, systemImage: "link")
                        .font(.caption)
                        .lineLimit(1)
                }
            }

            HStack(spacing: 16) {
                Label(proposal.proposer, systemImage: "person.circle")
                    .font(.caption)
                    .lineLimit(1)

                if let date = proposal.submissionDate {
                    Label {
                        Text(date, style: .relative)
                    } icon: {
                        Image(systemName: "clock")
                    }
                    .font(.caption)
                }
            }
            .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Kind Details

    @ViewBuilder
    private func proposalKindDetails(_ proposal: Proposal) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(proposal.displayKind, systemImage: proposal.displayIcon)
                .font(.headline)

            if let exchange = proposal.exchangeData {
                exchangeDetails(exchange)
            } else {
                switch proposal.kind {
                case .transfer(let action):
                    LabeledContent("Recipient", value: action.receiverId)
                    LabeledContent("Amount") {
                        if let tokenId = action.tokenId, !tokenId.isEmpty {
                            Text("\(action.amount) (token: \(tokenId))")
                        } else {
                            Text("\(formatNEAR(action.amount)) NEAR")
                        }
                    }

                case .addMemberToRole(let action):
                    LabeledContent("Account", value: action.memberId)
                    LabeledContent("Role", value: action.role)

                case .removeMemberFromRole(let action):
                    LabeledContent("Account", value: action.memberId)
                    LabeledContent("Role", value: action.role)

                case .functionCall(let action):
                    LabeledContent("Contract", value: action.receiverId)
                    ForEach(Array(action.actions.enumerated()), id: \.offset) { _, detail in
                        LabeledContent("Method", value: detail.methodName)
                    }

                default:
                    Text("Details not available for this proposal type.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Exchange Details

    @ViewBuilder
    private func exchangeDetails(_ exchange: ExchangeData) -> some View {
        // Swap summary
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Send")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Text(exchange.amountIn)
                            .font(.title3.weight(.semibold))
                        Text(exchange.tokenDisplayName(exchange.tokenIn))
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Receive")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Text(exchange.amountOut)
                            .font(.title3.weight(.semibold))
                        Text(exchange.tokenDisplayName(exchange.tokenOut))
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))

        // Additional details
        if let slippage = exchange.slippage {
            LabeledContent("Slippage Limit", value: "\(slippage)%")
        }

        if let timeEstimate = exchange.timeEstimate {
            LabeledContent("Estimated Time", value: timeEstimate)
        }

        if let deadline = exchange.quoteDeadline {
            LabeledContent("Quote Deadline", value: deadline)
        }

        if let depositAddress = exchange.depositAddress {
            LabeledContent("Deposit Address") {
                Text(depositAddress)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }

        if let notes = exchange.notes {
            VStack(alignment: .leading, spacing: 4) {
                Text("Notes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(notes)
                    .font(.subheadline)
            }
        }
    }

    // MARK: - Voting Progress Section

    @ViewBuilder
    private func votingProgressSection(_ proposal: Proposal) -> some View {
        let approvals = proposal.approvalCount
        let rejections = proposal.rejectionCount
        let hasUserVoted = proposal.userVote(accountId: currentAccountId) != nil

        VStack(alignment: .leading, spacing: 16) {
            Text("Voting")
                .font(.headline)

            // Only show threshold progress bar for pending proposals
            // (the current policy accurately reflects the required votes for active proposals,
            // but not for historical ones where membership may have changed)
            if proposal.status.isPending {
                let policy = treasuryService.policy
                let required = policy?.requiredVotes(for: proposal.kind, accountId: currentAccountId) ?? 1

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(approvals) of \(required) approvals")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        if rejections > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                                Text("\(rejections) rejected")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(.tertiarySystemFill))
                            Capsule()
                                .fill(approvals >= required ? Color.green : Color.accentColor)
                                .frame(width: geo.size.width * min(1.0, CGFloat(approvals) / CGFloat(max(required, 1))))
                        }
                    }
                    .frame(height: 8)
                }
            } else {
                // For completed proposals, show a summary without threshold
                HStack(spacing: 12) {
                    if approvals > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("\(approvals) approved")
                        }
                        .font(.subheadline.weight(.medium))
                    }
                    if rejections > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                            Text("\(rejections) rejected")
                        }
                        .font(.subheadline.weight(.medium))
                    }
                    if approvals == 0 && rejections == 0 {
                        Text("No votes were cast")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Individual voters
            if let votes = proposal.votes, !votes.isEmpty {
                Divider()

                VStack(spacing: 8) {
                    ForEach(Array(votes.keys.sorted()), id: \.self) { accountId in
                        if let voteStr = votes[accountId] {
                            let vote = Vote(rawValue: voteStr)
                            HStack(spacing: 8) {
                                Image(systemName: voteIcon(for: vote))
                                    .font(.body)
                                    .foregroundStyle(voteColor(for: vote))
                                    .frame(width: 24)

                                Text(accountId)
                                    .font(.subheadline)
                                    .lineLimit(1)

                                Spacer()

                                Text(voteStr)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(voteColor(for: vote).opacity(0.12), in: Capsule())
                                    .foregroundStyle(voteColor(for: vote))
                            }
                        }
                    }
                }
            } else if proposal.status.isPending {
                Text("No votes yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Vote actions (if pending and user hasn't voted)
            if proposal.status.isPending && !hasUserVoted && voteSuccess == nil {
                Divider()
                voteActions(proposal)
            } else if proposal.status.isPending && hasUserVoted && voteSuccess == nil {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(.secondary)
                    Text("You have already voted on this request.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Vote Actions

    @ViewBuilder
    private func voteActions(_ proposal: Proposal) -> some View {
        VStack(spacing: 12) {
            if let voteError {
                Text(voteError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 12) {
                Button {
                    pendingVote = .approve
                    showVoteConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Approve")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.green, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
                }
                .disabled(isVoting)

                Button {
                    pendingVote = .reject
                    showVoteConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("Reject")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.red, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
                }
                .disabled(isVoting)
            }

            if isVoting {
                ProgressView("Submitting vote...")
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

    private func voteIcon(for vote: Vote?) -> String {
        switch vote {
        case .approve: return "checkmark.circle.fill"
        case .reject: return "xmark.circle.fill"
        case .remove: return "trash.circle.fill"
        case nil: return "questionmark.circle"
        }
    }

    private func voteColor(for vote: Vote?) -> Color {
        switch vote {
        case .approve: return .green
        case .reject: return .red
        case .remove: return .orange
        case nil: return .secondary
        }
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
