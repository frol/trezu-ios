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

// MARK: - Config

struct DaoConfig: Codable {
    let name: String
    let purpose: String?
    let metadata: String?
}
