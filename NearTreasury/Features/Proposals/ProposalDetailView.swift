import SwiftUI

struct ProposalDetailView: View {
    @Environment(WalletManager.self) private var walletManager
    @State private var viewModel = ProposalDetailViewModel()
    @State private var showVoteSheet = false
    @State private var showConnectWalletPrompt = false

    let treasury: Treasury
    let proposal: Proposal
    let onVoteSubmitted: () -> Void

    private var canVote: Bool {
        walletManager.isConnected && proposal.status.isPending
    }

    private var hasVoted: Bool {
        guard let accountId = walletManager.currentAccountId else { return false }
        return proposal.hasVoted(accountId: accountId)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                headerSection

                Divider()

                // Voting section
                votingSection

                Divider()

                // Details section
                detailsSection

                // Votes list
                if let votes = proposal.votes, !votes.isEmpty {
                    Divider()
                    votesListSection(votes)
                }
            }
            .padding()
        }
        .navigationTitle("Proposal #\(proposal.id)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if proposal.status.isPending {
                ToolbarItem(placement: .primaryAction) {
                    if walletManager.isConnected {
                        if let accountId = walletManager.currentAccountId, !proposal.hasVoted(accountId: accountId) {
                            Button("Vote") {
                                showVoteSheet = true
                            }
                            .fontWeight(.semibold)
                        }
                    } else {
                        Button {
                            showConnectWalletPrompt = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "wallet.pass")
                                Text("Vote")
                            }
                            .fontWeight(.semibold)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showVoteSheet) {
            VoteSheet(
                treasury: treasury,
                proposal: proposal,
                isPresented: $showVoteSheet,
                onVoteSubmitted: onVoteSubmitted
            )
        }
        .sheet(isPresented: $showConnectWalletPrompt) {
            ConnectWalletSheet(
                isPresented: $showConnectWalletPrompt,
                message: "Connect your wallet to vote on this proposal",
                onConnected: {
                    // Show vote sheet after connecting
                    showVoteSheet = true
                }
            )
        }
        .loadingOverlay(isLoading: viewModel.isSubmitting, message: "Submitting vote...")
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ProposalStatusBadge(status: proposal.status)

                Text(proposal.kind.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .clipShape(Capsule())
            }

            Text(proposal.description)
                .font(.title3)
                .fontWeight(.semibold)

            HStack(spacing: 16) {
                // Proposer
                HStack(spacing: 6) {
                    AccountAvatar(accountId: proposal.proposer, size: 20)
                    Text(proposal.proposer)
                        .font(.caption)
                }

                // Time
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text(proposal.formattedSubmissionTime)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Voting Section

    private var votingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Voting")
                .font(.headline)

            VotingIndicator(
                approveCount: proposal.approveCount,
                rejectCount: proposal.rejectCount
            )

            if walletManager.isConnected {
                if let accountId = walletManager.currentAccountId {
                    if proposal.hasVoted(accountId: accountId) {
                        if let vote = proposal.voteOf(accountId: accountId) {
                            HStack(spacing: 8) {
                                Image(systemName: vote == .approve ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(vote == .approve ? .green : .red)

                                Text("You voted to \(vote == .approve ? "approve" : "reject")")
                                    .font(.subheadline)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                (vote == .approve ? Color.green : Color.red).opacity(0.1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    } else if proposal.status.isPending {
                        Button {
                            showVoteSheet = true
                        } label: {
                            Text("Cast Your Vote")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.blue)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            } else if proposal.status.isPending {
                // Not connected - show connect wallet prompt
                Button {
                    showConnectWalletPrompt = true
                } label: {
                    HStack {
                        Image(systemName: "wallet.pass")
                        Text("Connect Wallet to Vote")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(.headline)

            VStack(spacing: 12) {
                detailRow(label: "Type", value: proposal.kind.displayName)
                detailRow(label: "Status", value: proposal.status.displayName)
                detailRow(label: "Proposer", value: proposal.proposer)
                detailRow(label: "Proposal ID", value: "#\(proposal.id)")

                // Type-specific details
                switch proposal.kind {
                case .transfer(let transfer):
                    detailRow(label: "Receiver", value: transfer.receiverId)
                    detailRow(label: "Amount", value: formatAmount(transfer.amount))
                    if let tokenId = transfer.tokenId {
                        detailRow(label: "Token", value: tokenId)
                    }

                case .addMemberToRole(let addMember):
                    detailRow(label: "Member", value: addMember.memberId)
                    detailRow(label: "Role", value: addMember.role)

                case .removeMemberFromRole(let removeMember):
                    detailRow(label: "Member", value: removeMember.memberId)
                    detailRow(label: "Role", value: removeMember.role)

                case .functionCall(let functionCall):
                    detailRow(label: "Contract", value: functionCall.receiverId)
                    detailRow(label: "Method", value: functionCall.methodName)

                default:
                    EmptyView()
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - Votes List Section

    private func votesListSection(_ votes: [String: String]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Votes (\(votes.count))")
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(Array(votes.keys.sorted()), id: \.self) { voter in
                    if let vote = votes[voter] {
                        HStack(spacing: 12) {
                            AccountAvatar(accountId: voter, size: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(voter)
                                    .font(.subheadline)
                                    .lineLimit(1)
                            }

                            Spacer()

                            HStack(spacing: 4) {
                                Image(systemName: vote == "Approve" ? "checkmark" : "xmark")
                                    .font(.caption)
                                Text(vote)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundStyle(vote == "Approve" ? .green : .red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                (vote == "Approve" ? Color.green : Color.red).opacity(0.1)
                            )
                            .clipShape(Capsule())
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)

                        if voter != votes.keys.sorted().last {
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }
            }
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func formatAmount(_ amount: String) -> String {
        guard let value = Double(amount) else { return amount }
        let nearValue = value / pow(10, 24)
        if nearValue >= 1000 {
            return String(format: "%.2f NEAR", nearValue)
        } else {
            return String(format: "%.4f NEAR", nearValue)
        }
    }
}

#Preview {
    NavigationStack {
        ProposalDetailView(
            treasury: Treasury(daoId: "test.sputnik-dao.near", config: nil),
            proposal: Proposal(
                id: 1,
                description: "Transfer 100 NEAR to alice.near for development work",
                kind: .transfer(TransferKind(
                    tokenId: nil,
                    receiverId: "alice.near",
                    amount: "100000000000000000000000000",
                    msg: nil
                )),
                status: .inProgress,
                proposer: "bob.near",
                submissionTime: UInt64(Date().timeIntervalSince1970 * 1_000_000_000),
                voteCounts: ["council": [2, 0]],
                votes: ["bob.near": "Approve", "charlie.near": "Reject"]
            ),
            onVoteSubmitted: {}
        )
    }
    .environment(WalletManager.shared)
}
