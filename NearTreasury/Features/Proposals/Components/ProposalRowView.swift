import SwiftUI

struct ProposalRowView: View {
    let proposal: Proposal
    let currentAccountId: String?

    var body: some View {
        HStack(spacing: 12) {
            // Proposal type icon
            ZStack {
                Circle()
                    .fill(proposalColor.opacity(0.1))
                    .frame(width: 44, height: 44)

                Image(systemName: proposalIcon)
                    .font(.system(size: 18))
                    .foregroundStyle(proposalColor)
            }

            // Proposal info
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("#\(proposal.id)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    ProposalStatusBadge(status: proposal.status)
                }

                Text(proposal.kind.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(proposal.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 12) {
                    // Proposer
                    HStack(spacing: 4) {
                        Image(systemName: "person")
                            .font(.caption2)
                        Text(truncatedAddress(proposal.proposer))
                            .font(.caption)
                    }
                    .foregroundStyle(.tertiary)

                    // Time
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(proposal.formattedSubmissionTime)
                            .font(.caption)
                    }
                    .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Vote indicator
            VStack(alignment: .trailing, spacing: 8) {
                VotingIndicator(
                    approveCount: proposal.approveCount,
                    rejectCount: proposal.rejectCount
                )

                if let accountId = currentAccountId {
                    if proposal.hasVoted(accountId: accountId) {
                        if let vote = proposal.voteOf(accountId: accountId) {
                            HStack(spacing: 4) {
                                Image(systemName: vote == .approve ? "checkmark" : "xmark")
                                    .font(.caption2)
                                Text("Voted")
                                    .font(.caption)
                            }
                            .foregroundStyle(vote == .approve ? .green : .red)
                        }
                    } else if proposal.status.isPending {
                        Text("Vote")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var proposalIcon: String {
        switch proposal.kind {
        case .transfer:
            return "arrow.right.circle"
        case .functionCall:
            return "function"
        case .addMemberToRole:
            return "person.badge.plus"
        case .removeMemberFromRole:
            return "person.badge.minus"
        case .changePolicy:
            return "slider.horizontal.3"
        case .changeConfig:
            return "gearshape"
        case .upgradeRemote, .upgradeSelf:
            return "arrow.up.circle"
        case .setStakingContract:
            return "lock"
        case .bountyDone, .addBounty:
            return "gift"
        case .vote:
            return "hand.thumbsup"
        case .unknown:
            return "doc.text"
        }
    }

    private var proposalColor: Color {
        switch proposal.kind {
        case .transfer:
            return .blue
        case .functionCall:
            return .purple
        case .addMemberToRole:
            return .green
        case .removeMemberFromRole:
            return .red
        case .changePolicy, .changeConfig:
            return .orange
        case .upgradeRemote, .upgradeSelf:
            return .teal
        default:
            return .gray
        }
    }

    private func truncatedAddress(_ address: String) -> String {
        if address.count > 16 {
            return "\(address.prefix(6))...\(address.suffix(4))"
        }
        return address
    }
}

#Preview {
    List {
        ProposalRowView(
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
                votes: ["bob.near": "Approve"]
            ),
            currentAccountId: "test.near"
        )
    }
    .listStyle(.plain)
}
