import SwiftUI

struct VoteSheet: View {
    @Environment(WalletManager.self) private var walletManager
    @State private var viewModel = ProposalDetailViewModel()
    @State private var selectedVote: VoteAction?

    let treasury: Treasury
    let proposal: Proposal
    @Binding var isPresented: Bool
    let onVoteSubmitted: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Proposal summary
                VStack(spacing: 8) {
                    Text("Proposal #\(proposal.id)")
                        .font(.headline)

                    Text(proposal.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
                .padding()

                Divider()

                // Vote options
                VStack(spacing: 16) {
                    Text("Cast Your Vote")
                        .font(.title3)
                        .fontWeight(.semibold)

                    HStack(spacing: 16) {
                        // Approve button
                        VoteOptionButton(
                            vote: .approve,
                            isSelected: selectedVote == .approve,
                            action: { selectedVote = .approve }
                        )

                        // Reject button
                        VoteOptionButton(
                            vote: .reject,
                            isSelected: selectedVote == .reject,
                            action: { selectedVote = .reject }
                        )
                    }
                    .padding(.horizontal)
                }

                // Current votes
                VStack(spacing: 12) {
                    Text("Current Votes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    VotingIndicator(
                        approveCount: proposal.approveCount,
                        rejectCount: proposal.rejectCount
                    )
                }

                Spacer()

                // Error message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Submit button
                Button {
                    Task {
                        await submitVote()
                    }
                } label: {
                    HStack {
                        if viewModel.isSubmitting {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(viewModel.isSubmitting ? "Submitting..." : "Submit Vote")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedVote == nil ? Color.gray : Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(selectedVote == nil || viewModel.isSubmitting)
                .padding(.horizontal)
            }
            .padding(.vertical)
            .navigationTitle("Vote")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func submitVote() async {
        guard let vote = selectedVote else { return }

        do {
            try await viewModel.submitVote(
                treasuryId: treasury.daoId,
                proposal: proposal,
                vote: vote,
                walletManager: walletManager
            )

            isPresented = false
            onVoteSubmitted()
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }
}

struct VoteOptionButton: View {
    let vote: VoteAction
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(backgroundColor)
                        .frame(width: 64, height: 64)

                    Image(systemName: vote == .approve ? "checkmark" : "xmark")
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundStyle(iconColor)
                }

                Text(vote == .approve ? "Approve" : "Reject")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(textColor)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? selectedBackground : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? borderColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var iconColor: Color {
        if isSelected {
            return .white
        }
        return vote == .approve ? .green : .red
    }

    private var textColor: Color {
        isSelected ? (vote == .approve ? .green : .red) : .primary
    }

    private var backgroundColor: Color {
        if isSelected {
            return vote == .approve ? .green : .red
        }
        return (vote == .approve ? Color.green : Color.red).opacity(0.1)
    }

    private var selectedBackground: Color {
        (vote == .approve ? Color.green : Color.red).opacity(0.1)
    }

    private var borderColor: Color {
        vote == .approve ? .green : .red
    }
}

#Preview {
    VoteSheet(
        treasury: Treasury(daoId: "test.sputnik-dao.near", config: nil),
        proposal: Proposal(
            id: 1,
            description: "Transfer 100 NEAR to alice.near",
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
            votes: nil
        ),
        isPresented: .constant(true),
        onVoteSubmitted: {}
    )
    .environment(WalletManager.shared)
}
