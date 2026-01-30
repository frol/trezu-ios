import Foundation

@Observable
final class ProposalDetailViewModel {
    var isSubmitting = false
    var errorMessage: String?

    func submitVote(
        treasuryId: String,
        proposal: Proposal,
        vote: VoteAction,
        walletManager: WalletManager
    ) async throws {
        isSubmitting = true
        errorMessage = nil

        defer {
            isSubmitting = false
        }

        let transaction = TransactionBuilder.buildVoteTransaction(
            treasuryId: treasuryId,
            proposalId: proposal.id,
            vote: vote,
            proposalKind: proposal.kind.kindKey
        )

        _ = try await walletManager.signAndSendTransaction(transaction)
    }
}
