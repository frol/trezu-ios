import Foundation

struct Proposal: Codable, Identifiable, Hashable {
    let id: Int
    let description: String
    let kind: ProposalKind
    let status: ProposalStatus
    let proposer: String
    let submissionTime: UInt64
    let voteCounts: [String: [Int]]?
    let votes: [String: String]?

    enum CodingKeys: String, CodingKey {
        case id
        case description
        case kind
        case status
        case proposer
        case submissionTime = "submission_time"
        case voteCounts = "vote_counts"
        case votes
    }

    var formattedSubmissionTime: String {
        let nanoseconds = Double(submissionTime)
        let seconds = nanoseconds / 1_000_000_000
        let date = Date(timeIntervalSince1970: seconds)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var approveCount: Int {
        guard let counts = voteCounts else { return 0 }
        return counts.values.reduce(0) { sum, votes in
            sum + (votes.count > 0 ? votes[0] : 0)
        }
    }

    var rejectCount: Int {
        guard let counts = voteCounts else { return 0 }
        return counts.values.reduce(0) { sum, votes in
            sum + (votes.count > 1 ? votes[1] : 0)
        }
    }

    var totalVotes: Int {
        approveCount + rejectCount
    }

    func hasVoted(accountId: String) -> Bool {
        votes?[accountId] != nil
    }

    func voteOf(accountId: String) -> VoteAction? {
        guard let vote = votes?[accountId] else { return nil }
        return VoteAction(rawValue: vote)
    }
}

enum ProposalStatus: String, Codable {
    case approved = "Approved"
    case rejected = "Rejected"
    case inProgress = "InProgress"
    case expired = "Expired"
    case removed = "Removed"
    case failed = "Failed"

    var displayName: String {
        switch self {
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        case .inProgress: return "Pending"
        case .expired: return "Expired"
        case .removed: return "Removed"
        case .failed: return "Failed"
        }
    }

    var isPending: Bool {
        self == .inProgress
    }
}

enum ProposalKind: Codable, Hashable {
    case transfer(TransferKind)
    case functionCall(FunctionCallKind)
    case changePolicy(ChangePolicyKind)
    case addMemberToRole(AddMemberToRoleKind)
    case removeMemberFromRole(RemoveMemberFromRoleKind)
    case changeConfig(ChangeConfigKind)
    case upgradeRemote(UpgradeRemoteKind)
    case upgradeSelf(UpgradeSelfKind)
    case setStakingContract(SetStakingContractKind)
    case bountyDone(BountyDoneKind)
    case addBounty(AddBountyKind)
    case vote
    case unknown(String)

    var displayName: String {
        switch self {
        case .transfer: return "Transfer"
        case .functionCall: return "Function Call"
        case .changePolicy: return "Change Policy"
        case .addMemberToRole: return "Add Member"
        case .removeMemberFromRole: return "Remove Member"
        case .changeConfig: return "Change Config"
        case .upgradeRemote: return "Upgrade Remote"
        case .upgradeSelf: return "Upgrade Self"
        case .setStakingContract: return "Set Staking"
        case .bountyDone: return "Bounty Done"
        case .addBounty: return "Add Bounty"
        case .vote: return "Vote"
        case .unknown(let type): return type
        }
    }

    var kindKey: String {
        switch self {
        case .transfer: return "Transfer"
        case .functionCall: return "FunctionCall"
        case .changePolicy: return "ChangePolicy"
        case .addMemberToRole: return "AddMemberToRole"
        case .removeMemberFromRole: return "RemoveMemberFromRole"
        case .changeConfig: return "ChangeConfig"
        case .upgradeRemote: return "UpgradeRemote"
        case .upgradeSelf: return "UpgradeSelf"
        case .setStakingContract: return "SetStakingContract"
        case .bountyDone: return "BountyDone"
        case .addBounty: return "AddBounty"
        case .vote: return "Vote"
        case .unknown(let type): return type
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let stringValue = try? container.decode(String.self) {
            if stringValue == "Vote" {
                self = .vote
            } else {
                self = .unknown(stringValue)
            }
            return
        }

        let dict = try container.decode([String: AnyCodable].self)

        if let transfer = dict["Transfer"] {
            let data = try JSONEncoder().encode(transfer)
            let kind = try JSONDecoder().decode(TransferKind.self, from: data)
            self = .transfer(kind)
        } else if let functionCall = dict["FunctionCall"] {
            let data = try JSONEncoder().encode(functionCall)
            let kind = try JSONDecoder().decode(FunctionCallKind.self, from: data)
            self = .functionCall(kind)
        } else if let changePolicy = dict["ChangePolicy"] {
            let data = try JSONEncoder().encode(changePolicy)
            let kind = try JSONDecoder().decode(ChangePolicyKind.self, from: data)
            self = .changePolicy(kind)
        } else if let addMember = dict["AddMemberToRole"] {
            let data = try JSONEncoder().encode(addMember)
            let kind = try JSONDecoder().decode(AddMemberToRoleKind.self, from: data)
            self = .addMemberToRole(kind)
        } else if let removeMember = dict["RemoveMemberFromRole"] {
            let data = try JSONEncoder().encode(removeMember)
            let kind = try JSONDecoder().decode(RemoveMemberFromRoleKind.self, from: data)
            self = .removeMemberFromRole(kind)
        } else if let changeConfig = dict["ChangeConfig"] {
            let data = try JSONEncoder().encode(changeConfig)
            let kind = try JSONDecoder().decode(ChangeConfigKind.self, from: data)
            self = .changeConfig(kind)
        } else if dict["Vote"] != nil {
            self = .vote
        } else {
            self = .unknown(dict.keys.first ?? "Unknown")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .transfer(let kind):
            try container.encode(["Transfer": kind])
        case .functionCall(let kind):
            try container.encode(["FunctionCall": kind])
        case .changePolicy(let kind):
            try container.encode(["ChangePolicy": kind])
        case .addMemberToRole(let kind):
            try container.encode(["AddMemberToRole": kind])
        case .removeMemberFromRole(let kind):
            try container.encode(["RemoveMemberFromRole": kind])
        case .changeConfig(let kind):
            try container.encode(["ChangeConfig": kind])
        case .upgradeRemote(let kind):
            try container.encode(["UpgradeRemote": kind])
        case .upgradeSelf(let kind):
            try container.encode(["UpgradeSelf": kind])
        case .setStakingContract(let kind):
            try container.encode(["SetStakingContract": kind])
        case .bountyDone(let kind):
            try container.encode(["BountyDone": kind])
        case .addBounty(let kind):
            try container.encode(["AddBounty": kind])
        case .vote:
            try container.encode(["Vote": [:] as [String: String]])
        case .unknown(let type):
            try container.encode(type)
        }
    }
}

struct TransferKind: Codable, Hashable {
    let tokenId: String?
    let receiverId: String
    let amount: String
    let msg: String?

    enum CodingKeys: String, CodingKey {
        case tokenId = "token_id"
        case receiverId = "receiver_id"
        case amount
        case msg
    }
}

struct FunctionCallKind: Codable, Hashable {
    let receiverId: String
    let actions: [FunctionCallAction]

    enum CodingKeys: String, CodingKey {
        case receiverId = "receiver_id"
        case actions
    }

    // Convenience accessors for the first action
    var methodName: String? {
        actions.first?.methodName
    }

    var args: String? {
        actions.first?.args
    }

    var deposit: String? {
        actions.first?.deposit
    }
}

struct FunctionCallAction: Codable, Hashable {
    let methodName: String
    let args: String
    let deposit: String
    let gas: String?

    enum CodingKeys: String, CodingKey {
        case methodName = "method_name"
        case args
        case deposit
        case gas
    }
}

struct ChangePolicyKind: Codable, Hashable {
    let policy: AnyCodable?
}

struct AddMemberToRoleKind: Codable, Hashable {
    let memberId: String
    let role: String

    enum CodingKeys: String, CodingKey {
        case memberId = "member_id"
        case role
    }
}

struct RemoveMemberFromRoleKind: Codable, Hashable {
    let memberId: String
    let role: String

    enum CodingKeys: String, CodingKey {
        case memberId = "member_id"
        case role
    }
}

struct ChangeConfigKind: Codable, Hashable {
    let config: AnyCodable?
}

struct UpgradeRemoteKind: Codable, Hashable {
    let receiverId: String?
    let hash: String?

    enum CodingKeys: String, CodingKey {
        case receiverId = "receiver_id"
        case hash
    }
}

struct UpgradeSelfKind: Codable, Hashable {
    let hash: String?
}

struct SetStakingContractKind: Codable, Hashable {
    let stakingId: String?

    enum CodingKeys: String, CodingKey {
        case stakingId = "staking_id"
    }
}

struct BountyDoneKind: Codable, Hashable {
    let bountyId: Int?
    let receiverId: String?

    enum CodingKeys: String, CodingKey {
        case bountyId = "bounty_id"
        case receiverId = "receiver_id"
    }
}

struct AddBountyKind: Codable, Hashable {
    let bounty: AnyCodable?
}

enum VoteAction: String, Codable {
    case approve = "Approve"
    case reject = "Reject"
}

struct ProposalsResponse: Codable {
    let proposals: [Proposal]
    let total: Int?
}

struct ProposalFilters {
    var status: ProposalStatus?
    var proposer: String?
    var limit: Int = 50
    var offset: Int = 0

    var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]

        if let status = status {
            items.append(URLQueryItem(name: "status", value: status.rawValue))
        }

        if let proposer = proposer {
            items.append(URLQueryItem(name: "proposer", value: proposer))
        }

        return items
    }
}

// MARK: - AnyCodable Helper

struct AnyCodable: Codable, Hashable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            self.value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode AnyCodable"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Cannot encode AnyCodable"
                )
            )
        }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        String(describing: lhs.value) == String(describing: rhs.value)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(String(describing: value))
    }
}
