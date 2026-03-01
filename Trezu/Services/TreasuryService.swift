import Foundation
import NEARConnect

// MARK: - Treasury Service

/// Manages treasury data loading and caching.
@Observable
class TreasuryService {
    var treasuries: [Treasury] = []
    var selectedTreasury: Treasury?
    var policy: Policy?
    var assets: [TreasuryAsset] = []
    var balanceHistory: [BalanceHistoryPoint] = []
    var recentActivity: [ActivityItem] = []
    var members: [Member] = []
    var isLoading = false
    var error: String?

    private let api = APIClient.shared

    var totalBalanceUSD: Double {
        assets.compactMap(\.balanceUSD).reduce(0, +)
    }

    var daoId: String? { selectedTreasury?.daoId }

    // MARK: - Load Treasuries

    var accountId: String?

    func loadTreasuries() async {
        guard let accountId else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            treasuries = try await api.getUserTreasuries(accountId: accountId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Select Treasury

    func selectTreasury(_ treasury: Treasury) async {
        selectedTreasury = treasury
        // Load all data for the selected treasury in parallel
        await loadTreasuryData()
    }

    func loadTreasuryData() async {
        guard let daoId = daoId else { return }
        isLoading = true
        error = nil

        async let policyTask = loadPolicy(daoId: daoId)
        async let assetsTask = loadAssets(daoId: daoId)
        async let historyTask = loadBalanceHistory(daoId: daoId)
        async let activityTask = loadRecentActivity(daoId: daoId)

        _ = await (policyTask, assetsTask, historyTask, activityTask)

        // Derive members from policy roles
        if let policy = self.policy {
            self.members = Self.extractMembers(from: policy)
        }

        isLoading = false
    }

    // MARK: - Load Individual Data

    private func loadPolicy(daoId: String) async {
        do {
            policy = try await api.getTreasuryPolicy(daoId: daoId)
        } catch {
            print("Failed to load policy: \(error)")
        }
    }

    private func loadAssets(daoId: String) async {
        do {
            assets = try await api.getAssets(daoId: daoId)
        } catch {
            print("Failed to load assets: \(error)")
        }
    }

    private func loadBalanceHistory(daoId: String) async {
        do {
            balanceHistory = try await api.getBalanceHistory(daoId: daoId)
        } catch {
            print("Failed to load balance history: \(error)")
        }
    }

    private func loadRecentActivity(daoId: String) async {
        do {
            recentActivity = try await api.getRecentActivity(daoId: daoId)
        } catch {
            print("Failed to load recent activity: \(error)")
        }
    }

    // MARK: - Members

    static func extractMembers(from policy: Policy) -> [Member] {
        var memberMap: [String: Set<String>] = [:]

        for role in policy.roles {
            let accounts: [String]
            switch role.kind {
            case .group(let groupAccounts):
                accounts = groupAccounts
            case .member, .everyone:
                continue
            }

            for account in accounts {
                memberMap[account, default: []].insert(role.name)
            }
        }

        return memberMap.map { Member(accountId: $0.key, roles: Array($0.value).sorted()) }
            .sorted { $0.accountId < $1.accountId }
    }

    // MARK: - Proposals

    func loadProposals(
        statuses: [String] = [],
        page: Int = 1,
        search: String? = nil
    ) async throws -> PaginatedProposals {
        guard let daoId = daoId else {
            throw TreasuryError.noTreasurySelected
        }
        return try await api.getProposals(
            daoId: daoId,
            statuses: statuses,
            page: page,
            search: search
        )
    }

    func loadProposal(proposalId: Int) async throws -> Proposal {
        guard let daoId = daoId else {
            throw TreasuryError.noTreasurySelected
        }
        return try await api.getProposal(daoId: daoId, proposalId: proposalId)
    }

    // MARK: - Delegate Action Helpers

    /// Signs delegate actions via the wallet and relays through the backend.
    private func signAndRelay(
        daoId: String,
        methodName: String,
        args: [String: Any],
        gas: String = "300000000000000",
        deposit: String = "0",
        storageBytes: Int = 150,
        walletManager: NEARWalletManager
    ) async throws {
        // Args are passed as a plain dictionary; the wallet connector handles serialization
        let delegateActions: [[String: Any]] = [
            [
                "receiverId": daoId,
                "actions": [
                    [
                        "type": "FunctionCall",
                        "params": [
                            "methodName": methodName,
                            "args": args,
                            "gas": gas,
                            "deposit": deposit
                        ]
                    ]
                ]
            ]
        ]

        let result = try await walletManager.signDelegateActions(
            delegateActions: delegateActions
        )

        // signDelegateActions returns base64-encoded Borsh-serialized
        // SignedDelegateAction strings, ready to relay to the backend.
        guard !result.signedDelegateActions.isEmpty else {
            throw TreasuryError.delegateActionFailed("No signed delegate actions returned from wallet")
        }

        // Relay each signed delegate action to the backend
        for signedDelegateBase64 in result.signedDelegateActions {
            let relayResult = try await api.relayDelegateAction(
                signedDelegateAction: signedDelegateBase64,
                treasuryId: daoId,
                storageBytes: storageBytes
            )

            if !relayResult.success {
                throw TreasuryError.delegateActionFailed(relayResult.error ?? "Relay failed")
            }
        }
    }

    // MARK: - Voting

    func voteOnProposal(
        proposalId: Int,
        vote: Vote,
        rawKind: Any,
        walletManager: NEARWalletManager
    ) async throws {
        guard let daoId = daoId else {
            throw TreasuryError.noTreasurySelected
        }

        try await signAndRelay(
            daoId: daoId,
            methodName: "act_proposal",
            args: [
                "id": proposalId,
                "action": "Vote\(vote.rawValue)",
                "proposal": rawKind
            ],
            storageBytes: 150,
            walletManager: walletManager
        )
    }

    // MARK: - Create Proposals

    func createTransferProposal(
        description: String,
        receiverId: String,
        amount: String,
        tokenId: String?,
        walletManager: NEARWalletManager
    ) async throws {
        guard let daoId = daoId else {
            throw TreasuryError.noTreasurySelected
        }

        var transferKind: [String: Any] = [
            "receiver_id": receiverId,
            "amount": amount
        ]
        if let tokenId = tokenId {
            transferKind["token_id"] = tokenId
        }

        try await signAndRelay(
            daoId: daoId,
            methodName: "add_proposal",
            args: [
                "proposal": [
                    "description": description,
                    "kind": ["Transfer": transferKind]
                ]
            ],
            deposit: "100000000000000000000000", // 0.1 NEAR proposal bond
            storageBytes: 500,
            walletManager: walletManager
        )
    }

    func createAddMemberProposal(
        description: String,
        memberId: String,
        role: String,
        walletManager: NEARWalletManager
    ) async throws {
        guard let daoId = daoId else {
            throw TreasuryError.noTreasurySelected
        }

        try await signAndRelay(
            daoId: daoId,
            methodName: "add_proposal",
            args: [
                "proposal": [
                    "description": description,
                    "kind": [
                        "AddMemberToRole": [
                            "member_id": memberId,
                            "role": role
                        ]
                    ]
                ]
            ],
            deposit: "100000000000000000000000",
            storageBytes: 500,
            walletManager: walletManager
        )
    }

    func createRemoveMemberProposal(
        description: String,
        memberId: String,
        role: String,
        walletManager: NEARWalletManager
    ) async throws {
        guard let daoId = daoId else {
            throw TreasuryError.noTreasurySelected
        }

        try await signAndRelay(
            daoId: daoId,
            methodName: "add_proposal",
            args: [
                "proposal": [
                    "description": description,
                    "kind": [
                        "RemoveMemberFromRole": [
                            "member_id": memberId,
                            "role": role
                        ]
                    ]
                ]
            ],
            deposit: "100000000000000000000000",
            storageBytes: 500,
            walletManager: walletManager
        )
    }

    // MARK: - Refresh

    func refresh() async {
        await loadTreasuryData()
    }
}

// MARK: - Errors

enum TreasuryError: LocalizedError {
    case noTreasurySelected
    case delegateActionFailed(String)

    var errorDescription: String? {
        switch self {
        case .noTreasurySelected:
            return "No treasury selected"
        case .delegateActionFailed(let message):
            return "Delegate action failed: \(message)"
        }
    }
}
