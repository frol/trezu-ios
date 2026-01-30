import Foundation

struct Policy: Codable, Hashable {
    let roles: [PolicyRole]
    let defaultVotePolicy: VotePolicy?
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

    func membersForRole(_ role: String) -> [String] {
        guard let policyRole = roles.first(where: { $0.name == role }) else {
            return []
        }

        switch policyRole.kind {
        case .group(let members):
            return members
        case .member, .everyone:
            return []
        }
    }

    var allMembers: [Member] {
        var membersDict: [String: Set<String>] = [:]

        for role in roles {
            if case .group(let members) = role.kind {
                for member in members {
                    if membersDict[member] == nil {
                        membersDict[member] = []
                    }
                    membersDict[member]?.insert(role.name)
                }
            }
        }

        return membersDict.map { accountId, roles in
            Member(accountId: accountId, roles: Array(roles).sorted())
        }.sorted { $0.accountId < $1.accountId }
    }

    var roleNames: [String] {
        roles.map { $0.name }
    }

    func isMember(accountId: String) -> Bool {
        allMembers.contains { $0.accountId == accountId }
    }

    func rolesFor(accountId: String) -> [String] {
        allMembers.first { $0.accountId == accountId }?.roles ?? []
    }
}

struct PolicyRole: Codable, Hashable {
    let name: String
    let kind: RoleKind
    let permissions: [String]?
    let votePolicy: [String: VotePolicy]?

    enum CodingKeys: String, CodingKey {
        case name
        case kind
        case permissions
        case votePolicy = "vote_policy"
    }
}

enum RoleKind: Codable, Hashable {
    case everyone
    case member
    case group([String])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let stringValue = try? container.decode(String.self) {
            switch stringValue {
            case "Everyone":
                self = .everyone
            case "Member":
                self = .member
            default:
                self = .everyone
            }
            return
        }

        let dict = try container.decode([String: [String]].self)
        if let group = dict["Group"] {
            self = .group(group)
        } else {
            self = .everyone
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .everyone:
            try container.encode("Everyone")
        case .member:
            try container.encode("Member")
        case .group(let members):
            try container.encode(["Group": members])
        }
    }
}

struct VotePolicy: Codable, Hashable {
    let weightKind: String?
    let quorum: String?
    let threshold: ThresholdValue?

    enum CodingKeys: String, CodingKey {
        case weightKind = "weight_kind"
        case quorum
        case threshold
    }
}

enum ThresholdValue: Codable, Hashable {
    case ratio([Int])
    case weight(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let array = try? container.decode([Int].self) {
            self = .ratio(array)
        } else if let string = try? container.decode(String.self) {
            self = .weight(string)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode ThresholdValue"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .ratio(let values):
            try container.encode(values)
        case .weight(let value):
            try container.encode(value)
        }
    }
}

// Note: Policy API returns the policy object directly, not wrapped
