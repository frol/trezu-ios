import SwiftUI

struct PendingRequestsSection: View {
    let proposals: [Proposal]
    let treasuryId: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Pending Requests")
                    .font(.headline)

                Spacer()

                if proposals.count > 4 {
                    Text("View All")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            }

            if proposals.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(proposals.prefix(4))) { proposal in
                        PendingProposalRowView(proposal: proposal)

                        if proposal.id != proposals.prefix(4).last?.id {
                            Divider()
                                .padding(.leading, 12)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.05), radius: 4, y: 1)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.title)
                .foregroundStyle(.green)

            Text("No pending requests")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct PendingProposalRowView: View {
    let proposal: Proposal

    var body: some View {
        HStack(spacing: 12) {
            // Proposal type icon
            ZStack {
                Circle()
                    .fill(proposalColor.opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(systemName: proposalIcon)
                    .foregroundStyle(proposalColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(proposal.kind.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(proposal.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Vote counts
            HStack(spacing: 8) {
                VoteCountBadge(count: proposal.approveCount, type: .approve)
                VoteCountBadge(count: proposal.rejectCount, type: .reject)
            }
        }
        .padding(12)
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
        default:
            return "doc.text"
        }
    }

    private var proposalColor: Color {
        switch proposal.kind {
        case .transfer:
            return .blue
        case .addMemberToRole:
            return .green
        case .removeMemberFromRole:
            return .red
        case .changePolicy, .changeConfig:
            return .orange
        default:
            return .purple
        }
    }
}

struct VoteCountBadge: View {
    let count: Int
    let type: VoteType

    enum VoteType {
        case approve
        case reject
    }

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: type == .approve ? "checkmark" : "xmark")
                .font(.caption2)

            Text("\(count)")
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(type == .approve ? .green : .red)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            (type == .approve ? Color.green : Color.red).opacity(0.1)
        )
        .clipShape(Capsule())
    }
}

#Preview {
    PendingRequestsSection(
        proposals: [],
        treasuryId: "test.sputnik-dao.near"
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
