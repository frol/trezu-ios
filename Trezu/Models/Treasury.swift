import Foundation

// MARK: - Treasury

struct Treasury: Codable, Identifiable, Hashable {
    var id: String { daoId }
    let daoId: String
    let config: TreasuryConfig
    let isMember: Bool
    let isSaved: Bool
    let isHidden: Bool

    var name: String { config.name ?? daoId }
    var purpose: String? { config.purpose }
}

struct TreasuryConfig: Codable, Hashable {
    let metadata: TreasuryMetadataInfo?
    let name: String?
    let purpose: String?
}

struct TreasuryMetadataInfo: Codable, Hashable {
    let primaryColor: String?
    let flagLogo: String?
}

// MARK: - Policy

struct Policy: Codable {
    let roles: [RolePermission]
    let defaultVotePolicy: VotePolicy
    let proposalBond: String?
    let proposalPeriod: String?
    let bountyBond: String?
    let bountyForgivenessPeriod: String?

    enum CodingKeys: String, CodingKey {
        case roles
        case defaultVotePolicy = "default_vote_policy"
        case proposalBond = "proposal_bond"
        case proposalPeriod = "proposal_period"
        case bountyBond = "bounty_bond"
        case bountyForgivenessPeriod = "bounty_forgiveness_period"
    }
}

// MARK: - RolePermission

struct RolePermission: Codable, Identifiable {
    var id: String { name }
    let name: String
    let kind: RoleKind
    let permissions: [String]?
    let votePolicy: [String: VotePolicy]?

    enum CodingKeys: String, CodingKey {
        case name, kind, permissions
        case votePolicy = "vote_policy"
    }
}

enum RoleKind: Codable {
    case everyone
    case member(String)
    case group([String])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self), str == "Everyone" {
            self = .everyone
            return
        }
        let dict = try container.decode([String: RoleKindValue].self)
        if let memberValue = dict["Member"] {
            if case .string(let s) = memberValue {
                self = .member(s)
            } else {
                self = .member("")
            }
        } else if let groupValue = dict["Group"] {
            if case .array(let arr) = groupValue {
                self = .group(arr)
            } else {
                self = .group([])
            }
        } else {
            self = .everyone
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .everyone:
            try container.encode("Everyone")
        case .member(let s):
            try container.encode(["Member": s])
        case .group(let arr):
            try container.encode(["Group": arr])
        }
    }

    var memberAccounts: [String] {
        switch self {
        case .everyone: return []
        case .member: return []
        case .group(let accounts): return accounts
        }
    }
}

private enum RoleKindValue: Codable {
    case string(String)
    case array([String])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) {
            self = .string(s)
            return
        }
        let arr = try container.decode([String].self)
        self = .array(arr)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .array(let arr): try container.encode(arr)
        }
    }
}

// MARK: - VotePolicy

struct VotePolicy: Codable {
    let weightKind: String?
    let quorum: String?
    let threshold: ThresholdValue?

    enum CodingKeys: String, CodingKey {
        case weightKind = "weight_kind"
        case quorum, threshold
    }
}

enum ThresholdValue: Codable {
    case absolute(Int)
    case ratio(Int, Int)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let num = try? container.decode(Int.self) {
            self = .absolute(num)
            return
        }
        if let arr = try? container.decode([Int].self), arr.count == 2 {
            self = .ratio(arr[0], arr[1])
            return
        }
        // Handle string format like "1/2" or plain number strings
        if let str = try? container.decode(String.self) {
            let parts = str.split(separator: "/")
            if parts.count == 2, let num = Int(parts[0]), let den = Int(parts[1]) {
                self = .ratio(num, den)
                return
            }
            if let num = Int(str) {
                self = .absolute(num)
                return
            }
        }
        self = .absolute(0)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .absolute(let n): try container.encode(n)
        case .ratio(let a, let b): try container.encode([a, b])
        }
    }

    var displayString: String {
        switch self {
        case .absolute(let n): return "\(n)"
        case .ratio(let num, let den):
            if den > 0 {
                let pct = Int(Double(num) / Double(den) * 100)
                return "\(pct)%"
            }
            return "\(num)/\(den)"
        }
    }
}

// MARK: - Voting Threshold

extension Policy {
    /// Computes the required number of approval votes for a proposal of the given kind.
    /// Replicates the frontend's `getApproversAndThreshold` logic.
    func requiredVotes(for proposalKind: ProposalKind, accountId: String) -> Int {
        let kind = proposalKind.permissionKind
        let approvePermissions: Set<String> = [
            "*:*", "\(kind):*",
            "\(kind):VoteApprove", "\(kind):VoteReject",
            "*:VoteApprove", "*:VoteReject"
        ]

        // Find roles that have voting permission for this kind
        let rolesWithPermission = roles.filter { role in
            guard let permissions = role.permissions else { return false }
            return permissions.contains { approvePermissions.contains($0) }
        }

        var approverAccounts: Set<String> = []
        var ratios: [Int] = []
        var absoluteVotes: Int?
        var everyoneHasAccess = false

        for role in rolesWithPermission {
            // Collect group members
            if case .group(let accounts) = role.kind {
                approverAccounts.formUnion(accounts)
            }
            if case .everyone = role.kind {
                everyoneHasAccess = true
            }

            // Determine vote policy: role-specific or default
            let votePolicy: VotePolicy
            if let rolePolicies = role.votePolicy,
               let specific = rolePolicies[kind],
               specific.threshold != nil {
                votePolicy = specific
            } else {
                votePolicy = defaultVotePolicy
            }

            if votePolicy.weightKind == "RoleWeight" {
                if let threshold = votePolicy.threshold {
                    switch threshold {
                    case .ratio(let num, let den):
                        ratios.append(contentsOf: [num, den])
                    case .absolute(let n):
                        absoluteVotes = n
                    }
                }
            }
        }

        if everyoneHasAccess && !accountId.isEmpty {
            approverAccounts.insert(accountId)
        }

        if let absolute = absoluteVotes {
            return absolute
        }

        // Compute from ratio: floor(numerator/denominator * memberCount) + 1
        guard !ratios.isEmpty else { return 1 }
        var numerator = 0
        var denominator = 0
        for (i, val) in ratios.enumerated() {
            if i % 2 == 0 { numerator += val }
            else { denominator += val }
        }
        guard denominator > 0 else { return 1 }
        return Int(Double(numerator) / Double(denominator) * Double(approverAccounts.count)) + 1
    }

    /// Returns the list of accounts that can vote on proposals of the given kind.
    func approverAccounts(for proposalKind: ProposalKind, accountId: String) -> [String] {
        let kind = proposalKind.permissionKind
        let approvePermissions: Set<String> = [
            "*:*", "\(kind):*",
            "\(kind):VoteApprove", "\(kind):VoteReject",
            "*:VoteApprove", "*:VoteReject"
        ]

        let rolesWithPermission = roles.filter { role in
            guard let permissions = role.permissions else { return false }
            return permissions.contains { approvePermissions.contains($0) }
        }

        var accounts: Set<String> = []
        var everyoneHasAccess = false
        for role in rolesWithPermission {
            if case .group(let groupAccounts) = role.kind {
                accounts.formUnion(groupAccounts)
            }
            if case .everyone = role.kind {
                everyoneHasAccess = true
            }
        }
        if everyoneHasAccess && !accountId.isEmpty {
            accounts.insert(accountId)
        }
        return Array(accounts).sorted()
    }
}

// MARK: - Config

struct DaoConfig: Codable {
    let name: String
    let purpose: String?
    let metadata: String?
}
