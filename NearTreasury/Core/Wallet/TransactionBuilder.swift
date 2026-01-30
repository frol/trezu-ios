import Foundation

struct TransactionBuilder {
    static let defaultGas = "100000000000000" // 100 TGas
    static let zeroDeposit = "0"
    static let oneYocto = "1"

    // MARK: - Vote Transaction

    static func buildVoteTransaction(
        treasuryId: String,
        proposalId: Int,
        vote: VoteAction,
        proposalKind: String
    ) -> WalletTransaction {
        let action = WalletAction.functionCall(
            WalletAction.FunctionCallAction(
                methodName: "act_proposal",
                args: [
                    "id": AnyCodable(proposalId),
                    "action": AnyCodable("Vote\(vote.rawValue)"),
                    "proposal": AnyCodable(proposalKind)
                ],
                gas: defaultGas,
                deposit: zeroDeposit
            )
        )

        return WalletTransaction(
            receiverId: treasuryId,
            actions: [action]
        )
    }

    // MARK: - Batch Vote Transaction

    static func buildBatchVoteTransactions(
        treasuryId: String,
        proposals: [(id: Int, kind: String)],
        vote: VoteAction
    ) -> [WalletTransaction] {
        proposals.map { proposal in
            buildVoteTransaction(
                treasuryId: treasuryId,
                proposalId: proposal.id,
                vote: vote,
                proposalKind: proposal.kind
            )
        }
    }

    // MARK: - Transfer Proposal Transaction

    static func buildTransferProposalTransaction(
        treasuryId: String,
        description: String,
        receiverId: String,
        amount: String,
        tokenId: String? = nil
    ) -> WalletTransaction {
        var transferArgs: [String: AnyCodable] = [
            "receiver_id": AnyCodable(receiverId),
            "amount": AnyCodable(amount)
        ]

        if let tokenId = tokenId {
            transferArgs["token_id"] = AnyCodable(tokenId)
        }

        let proposalKind: [String: AnyCodable] = [
            "Transfer": AnyCodable(transferArgs)
        ]

        let action = WalletAction.functionCall(
            WalletAction.FunctionCallAction(
                methodName: "add_proposal",
                args: [
                    "proposal": AnyCodable([
                        "description": description,
                        "kind": proposalKind
                    ] as [String: Any])
                ],
                gas: defaultGas,
                deposit: oneYocto
            )
        )

        return WalletTransaction(
            receiverId: treasuryId,
            actions: [action]
        )
    }

    // MARK: - Add Member Proposal Transaction

    static func buildAddMemberProposalTransaction(
        treasuryId: String,
        description: String,
        memberId: String,
        role: String
    ) -> WalletTransaction {
        let proposalKind: [String: AnyCodable] = [
            "AddMemberToRole": AnyCodable([
                "member_id": memberId,
                "role": role
            ] as [String: Any])
        ]

        let action = WalletAction.functionCall(
            WalletAction.FunctionCallAction(
                methodName: "add_proposal",
                args: [
                    "proposal": AnyCodable([
                        "description": description,
                        "kind": proposalKind
                    ] as [String: Any])
                ],
                gas: defaultGas,
                deposit: oneYocto
            )
        )

        return WalletTransaction(
            receiverId: treasuryId,
            actions: [action]
        )
    }

    // MARK: - Remove Member Proposal Transaction

    static func buildRemoveMemberProposalTransaction(
        treasuryId: String,
        description: String,
        memberId: String,
        role: String
    ) -> WalletTransaction {
        let proposalKind: [String: AnyCodable] = [
            "RemoveMemberFromRole": AnyCodable([
                "member_id": memberId,
                "role": role
            ] as [String: Any])
        ]

        let action = WalletAction.functionCall(
            WalletAction.FunctionCallAction(
                methodName: "add_proposal",
                args: [
                    "proposal": AnyCodable([
                        "description": description,
                        "kind": proposalKind
                    ] as [String: Any])
                ],
                gas: defaultGas,
                deposit: oneYocto
            )
        )

        return WalletTransaction(
            receiverId: treasuryId,
            actions: [action]
        )
    }

    // MARK: - Function Call Proposal Transaction

    static func buildFunctionCallProposalTransaction(
        treasuryId: String,
        description: String,
        receiverId: String,
        methodName: String,
        args: String,
        deposit: String,
        gas: String? = nil
    ) -> WalletTransaction {
        let functionCallArgs: [String: AnyCodable] = [
            "receiver_id": AnyCodable(receiverId),
            "method_name": AnyCodable(methodName),
            "args": AnyCodable(args),
            "deposit": AnyCodable(deposit),
            "gas": AnyCodable(gas ?? defaultGas)
        ]

        let proposalKind: [String: AnyCodable] = [
            "FunctionCall": AnyCodable(functionCallArgs)
        ]

        let action = WalletAction.functionCall(
            WalletAction.FunctionCallAction(
                methodName: "add_proposal",
                args: [
                    "proposal": AnyCodable([
                        "description": description,
                        "kind": proposalKind
                    ] as [String: Any])
                ],
                gas: defaultGas,
                deposit: oneYocto
            )
        )

        return WalletTransaction(
            receiverId: treasuryId,
            actions: [action]
        )
    }
}
