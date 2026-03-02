import Foundation

// MARK: - Proposal

struct Proposal: Codable, Identifiable {
    let id: Int
    let daoId: String?
    let proposer: String
    let description: String
    let kind: ProposalKind
    let status: ProposalStatus
    let voteCounts: [String: [String]]?
    let votes: [String: String]?
    let submissionTime: String?

    /// The original JSON value of the `kind` field, preserved exactly as received from the API.
    /// Used as the `proposal` argument when voting via `act_proposal`.
    let rawKind: Any

    enum CodingKeys: String, CodingKey {
        case id
        case daoId = "dao_id"
        case proposer, description, kind, status
        case voteCounts = "vote_counts"
        case votes
        case submissionTime = "submission_time"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        daoId = try container.decodeIfPresent(String.self, forKey: .daoId)
        proposer = try container.decode(String.self, forKey: .proposer)
        description = try container.decode(String.self, forKey: .description)
        kind = try container.decode(ProposalKind.self, forKey: .kind)
        status = try container.decode(ProposalStatus.self, forKey: .status)
        // vote_counts values can be arrays of strings or ints depending on the DAO contract version
        if let rawVoteCounts = try container.decodeIfPresent([String: AnyCodable].self, forKey: .voteCounts) {
            var parsed: [String: [String]] = [:]
            for (role, anyCodable) in rawVoteCounts {
                if let arr = anyCodable.value as? [Any] {
                    parsed[role] = arr.map { "\($0)" }
                }
            }
            voteCounts = parsed.isEmpty ? nil : parsed
        } else {
            voteCounts = nil
        }
        votes = try container.decodeIfPresent([String: String].self, forKey: .votes)
        submissionTime = try container.decodeIfPresent(String.self, forKey: .submissionTime)
        // Preserve the raw kind JSON for use in act_proposal
        let rawKindCodable = try container.decode(AnyCodable.self, forKey: .kind)
        rawKind = rawKindCodable.value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(daoId, forKey: .daoId)
        try container.encode(proposer, forKey: .proposer)
        try container.encode(description, forKey: .description)
        try container.encode(kind, forKey: .kind)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(voteCounts, forKey: .voteCounts)
        try container.encodeIfPresent(votes, forKey: .votes)
        try container.encodeIfPresent(submissionTime, forKey: .submissionTime)
    }

    var submissionDate: Date? {
        guard let ts = submissionTime else { return nil }
        // NEAR timestamps are in nanoseconds
        if let nanos = Double(ts) {
            return Date(timeIntervalSince1970: nanos / 1_000_000_000)
        }
        return nil
    }

    var decodedDescription: ProposalDescription {
        ProposalDescription.parse(description)
    }

    /// Whether this proposal is an exchange/swap request.
    var isExchange: Bool {
        decodedDescription.fields["proposalAction"] == "asset-exchange"
    }

    /// Extracted exchange data, if this is an exchange proposal.
    var exchangeData: ExchangeData? {
        guard isExchange else { return nil }
        let fields = decodedDescription.fields
        return ExchangeData(
            tokenIn: fields["tokenIn"] ?? fields["tokenInAddress"] ?? "",
            tokenOut: fields["tokenOut"] ?? fields["tokenOutAddress"] ?? "",
            amountIn: fields["amountIn"] ?? "",
            amountOut: fields["amountOut"] ?? "",
            slippage: fields["slippage"],
            quoteDeadline: fields["quoteDeadline"],
            timeEstimate: fields["timeEstimate"],
            depositAddress: fields["depositAddress"],
            notes: fields["notes"]
        )
    }

    /// The display name for the proposal kind, accounting for exchange proposals.
    var displayKind: String {
        isExchange ? "Exchange" : kind.displayName
    }

    /// The icon for the proposal kind, accounting for exchange proposals.
    var displayIcon: String {
        isExchange ? "arrow.triangle.swap" : kind.iconName
    }

    func userVote(accountId: String) -> Vote? {
        guard let voteStr = votes?[accountId] else { return nil }
        return Vote(rawValue: voteStr)
    }

    /// Number of approval votes cast.
    var approvalCount: Int {
        votes?.values.filter { $0 == Vote.approve.rawValue }.count ?? 0
    }

    /// Number of rejection votes cast.
    var rejectionCount: Int {
        votes?.values.filter { $0 == Vote.reject.rawValue }.count ?? 0
    }
}

// MARK: - Exchange Data

struct ExchangeData {
    let tokenIn: String
    let tokenOut: String
    let amountIn: String
    let amountOut: String
    let slippage: String?
    let quoteDeadline: String?
    let timeEstimate: String?
    let depositAddress: String?
    let notes: String?

    /// Shortened token name for display (e.g. "17208628f84f5d6...33a1" → last segment or truncated).
    func tokenDisplayName(_ token: String) -> String {
        // Known tokens
        let knownTokens: [String: String] = [
            "near": "NEAR",
            "wrap.near": "wNEAR",
            "usdt.tether-token.near": "USDt",
        ]
        if let name = knownTokens[token.lowercased()] {
            return name
        }
        // If it's a .near address, use it as-is
        if token.hasSuffix(".near") {
            return token
        }
        // Long hex-like contract IDs → truncate
        if token.count > 20 {
            return "\(token.prefix(6))…\(token.suffix(4))"
        }
        return token
    }
}

// MARK: - ProposalDescription

struct ProposalDescription {
    let title: String
    let notes: String?
    let url: String?
    let fields: [String: String]

    /// Parses a proposal description string.
    ///
    /// Supports two formats used by the treasury frontend:
    /// 1. JSON: `{"title": "...", "notes": "...", "url": "..."}`
    /// 2. Markdown: `* Key Name: value <br> * Another Key: value`
    ///
    /// Falls back to using the raw string as the title.
    static func parse(_ raw: String) -> ProposalDescription {
        // 1. Try JSON
        if let data = raw.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let fields = json.compactMapValues { $0 as? String }
            return ProposalDescription(
                title: fields["title"] ?? raw,
                notes: fields["notes"],
                url: fields["url"],
                fields: fields
            )
        }

        // 2. Try markdown-like format: "* Key Name: value <br> * Key: value"
        let fields = parseMarkdownFields(raw)
        if !fields.isEmpty {
            // "title" takes precedence over "notes" for display
            let title = fields["title"] ?? fields["notes"]
            return ProposalDescription(
                title: title ?? raw,
                notes: title != nil ? fields["notes"] : nil,
                url: fields["url"],
                fields: fields
            )
        }

        // 3. Plain text fallback
        return ProposalDescription(title: raw, notes: nil, url: nil, fields: [:])
    }

    /// Parses the `* Key Name: value <br> * Key: value` markdown format into a dictionary.
    /// Keys are normalized to camelCase for consistent lookup.
    private static func parseMarkdownFields(_ raw: String) -> [String: String] {
        var result: [String: String] = [:]
        let segments = raw.components(separatedBy: "<br>")
        for segment in segments {
            let trimmed = segment.trimmingCharacters(in: .whitespacesAndNewlines)
            // Strip leading "* " or "- "
            let content: String
            if trimmed.hasPrefix("* ") {
                content = String(trimmed.dropFirst(2))
            } else if trimmed.hasPrefix("- ") {
                content = String(trimmed.dropFirst(2))
            } else {
                content = trimmed
            }

            guard let colonIndex = content.firstIndex(of: ":") else { continue }
            let key = content[content.startIndex..<colonIndex].trimmingCharacters(in: .whitespaces)
            let value = content[content.index(after: colonIndex)...].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty, !value.isEmpty else { continue }

            let normalizedKey = normalizeKey(key)
            result[normalizedKey] = value
        }
        return result
    }

    /// Converts a "Title Case" or "Space Separated" key to camelCase.
    /// e.g. "Proposal Action" → "proposalAction", "Notes" → "notes"
    private static func normalizeKey(_ key: String) -> String {
        let words = key.split(separator: " ")
        guard let first = words.first else { return key.lowercased() }
        let head = first.lowercased()
        let tail = words.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
        return head + tail.joined()
    }
}

// MARK: - ProposalStatus

enum ProposalStatus: String, Codable, CaseIterable {
    case approved = "Approved"
    case rejected = "Rejected"
    case inProgress = "InProgress"
    case expired = "Expired"
    case removed = "Removed"
    case moved = "Moved"
    case failed = "Failed"

    var displayName: String {
        switch self {
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        case .inProgress: return "Pending"
        case .expired: return "Expired"
        case .removed: return "Removed"
        case .moved: return "Moved"
        case .failed: return "Failed"
        }
    }

    var isPending: Bool { self == .inProgress }
}

// MARK: - Vote

enum Vote: String, Codable {
    case approve = "Approve"
    case reject = "Reject"
    case remove = "Remove"
}

// MARK: - ProposalKind

enum ProposalKind: Codable {
    case transfer(TransferAction)
    case functionCall(FunctionCallAction)
    case addMemberToRole(AddMemberAction)
    case removeMemberFromRole(RemoveMemberAction)
    case changePolicy(ChangePolicyAction)
    case changeConfig(ChangeConfigAction)
    case upgradeSelf(UpgradeAction)
    case upgradeRemote(UpgradeRemoteAction)
    case setStakingContract(SetStakingAction)
    case addBounty(AddBountyAction)
    case bountyDone(BountyDoneAction)
    case vote
    case factoryInfoUpdate
    case unknown(String)

    var displayName: String {
        switch self {
        case .transfer: return "Transfer"
        case .functionCall: return "Function Call"
        case .addMemberToRole: return "Add Member"
        case .removeMemberFromRole: return "Remove Member"
        case .changePolicy: return "Change Policy"
        case .changeConfig: return "Change Config"
        case .upgradeSelf: return "Upgrade"
        case .upgradeRemote: return "Remote Upgrade"
        case .setStakingContract: return "Set Staking"
        case .addBounty: return "Add Bounty"
        case .bountyDone: return "Bounty Done"
        case .vote: return "Vote"
        case .factoryInfoUpdate: return "Factory Update"
        case .unknown(let s): return s
        }
    }

    /// The permission kind string used in policy role permissions (e.g. "transfer", "call", "policy").
    var permissionKind: String {
        switch self {
        case .transfer: return "transfer"
        case .functionCall: return "call"
        case .addMemberToRole: return "add_member_to_role"
        case .removeMemberFromRole: return "remove_member_from_role"
        case .changePolicy: return "policy"
        case .changeConfig: return "config"
        case .upgradeSelf: return "upgrade_self"
        case .upgradeRemote: return "upgrade_remote"
        case .setStakingContract: return "set_staking_contract"
        case .addBounty: return "add_bounty"
        case .bountyDone: return "bounty_done"
        case .vote: return "vote"
        case .factoryInfoUpdate: return "factory_info_update"
        case .unknown: return "unknown"
        }
    }

    var iconName: String {
        switch self {
        case .transfer: return "arrow.right.circle"
        case .functionCall: return "terminal"
        case .addMemberToRole: return "person.badge.plus"
        case .removeMemberFromRole: return "person.badge.minus"
        case .changePolicy: return "shield.checkered"
        case .changeConfig: return "gearshape"
        case .upgradeSelf, .upgradeRemote: return "arrow.up.circle"
        case .setStakingContract: return "lock.circle"
        case .addBounty, .bountyDone: return "gift"
        case .vote: return "hand.thumbsup"
        case .factoryInfoUpdate: return "info.circle"
        case .unknown: return "questionmark.circle"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dict = try container.decode([String: AnyCodable].self)

        if let transfer = dict["Transfer"] {
            let data = try JSONSerialization.data(withJSONObject: transfer.value)
            let action = try JSONDecoder().decode(TransferAction.self, from: data)
            self = .transfer(action)
        } else if let fc = dict["FunctionCall"] {
            let data = try JSONSerialization.data(withJSONObject: fc.value)
            let action = try JSONDecoder().decode(FunctionCallAction.self, from: data)
            self = .functionCall(action)
        } else if let add = dict["AddMemberToRole"] {
            let data = try JSONSerialization.data(withJSONObject: add.value)
            let action = try JSONDecoder().decode(AddMemberAction.self, from: data)
            self = .addMemberToRole(action)
        } else if let rem = dict["RemoveMemberFromRole"] {
            let data = try JSONSerialization.data(withJSONObject: rem.value)
            let action = try JSONDecoder().decode(RemoveMemberAction.self, from: data)
            self = .removeMemberFromRole(action)
        } else if let cp = dict["ChangePolicy"] {
            let data = try JSONSerialization.data(withJSONObject: cp.value)
            let action = try JSONDecoder().decode(ChangePolicyAction.self, from: data)
            self = .changePolicy(action)
        } else if let cc = dict["ChangeConfig"] {
            let data = try JSONSerialization.data(withJSONObject: cc.value)
            let action = try JSONDecoder().decode(ChangeConfigAction.self, from: data)
            self = .changeConfig(action)
        } else if dict["Vote"] != nil {
            self = .vote
        } else {
            let key = dict.keys.first ?? "Unknown"
            self = .unknown(key)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .transfer(let a):
            try container.encode(["Transfer": AnyCodable(a)])
        case .functionCall(let a):
            try container.encode(["FunctionCall": AnyCodable(a)])
        case .addMemberToRole(let a):
            try container.encode(["AddMemberToRole": AnyCodable(a)])
        case .removeMemberFromRole(let a):
            try container.encode(["RemoveMemberFromRole": AnyCodable(a)])
        default:
            try container.encode(["Unknown": AnyCodable("unsupported")])
        }
    }
}

// MARK: - ProposalKind Actions

struct TransferAction: Codable {
    let tokenId: String?
    let receiverId: String
    let amount: String
    let msg: String?

    enum CodingKeys: String, CodingKey {
        case tokenId = "token_id"
        case receiverId = "receiver_id"
        case amount, msg
    }
}

struct FunctionCallAction: Codable {
    let receiverId: String
    let actions: [FunctionCallDetail]

    enum CodingKeys: String, CodingKey {
        case receiverId = "receiver_id"
        case actions
    }
}

struct FunctionCallDetail: Codable {
    let methodName: String
    let args: String
    let deposit: String
    let gas: String

    enum CodingKeys: String, CodingKey {
        case methodName = "method_name"
        case args, deposit, gas
    }

    var decodedArgs: [String: Any]? {
        guard let data = Data(base64Encoded: args) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}

struct AddMemberAction: Codable {
    let memberId: String
    let role: String

    enum CodingKeys: String, CodingKey {
        case memberId = "member_id"
        case role
    }
}

struct RemoveMemberAction: Codable {
    let memberId: String
    let role: String

    enum CodingKeys: String, CodingKey {
        case memberId = "member_id"
        case role
    }
}

struct ChangePolicyAction: Codable {
    let policy: Policy?
}

struct ChangeConfigAction: Codable {
    let config: DaoConfig?
}

struct UpgradeAction: Codable {
    let hash: String?
}

struct UpgradeRemoteAction: Codable {
    let receiverId: String?
    let hash: String?

    enum CodingKeys: String, CodingKey {
        case receiverId = "receiver_id"
        case hash
    }
}

struct SetStakingAction: Codable {
    let stakingId: String?

    enum CodingKeys: String, CodingKey {
        case stakingId = "staking_id"
    }
}

struct AddBountyAction: Codable {
    let bounty: AnyCodable?
}

struct BountyDoneAction: Codable {
    let bountyId: Int?
    let receiverId: String?

    enum CodingKeys: String, CodingKey {
        case bountyId = "bounty_id"
        case receiverId = "receiver_id"
    }
}

// MARK: - Paginated Response

struct PaginatedProposals: Codable {
    let proposals: [Proposal]
    let total: Int
    let page: Int
    let pageSize: Int

    enum CodingKeys: String, CodingKey {
        case proposals, total, page
        case pageSize = "page_size"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        total = try container.decode(Int.self, forKey: .total)
        page = try container.decode(Int.self, forKey: .page)
        pageSize = try container.decode(Int.self, forKey: .pageSize)
        // Decode proposals individually — skip any that fail to parse
        var proposalsContainer = try container.nestedUnkeyedContainer(forKey: .proposals)
        var parsed: [Proposal] = []
        while !proposalsContainer.isAtEnd {
            if let proposal = try? proposalsContainer.decode(Proposal.self) {
                parsed.append(proposal)
            } else {
                // Skip the failed element by decoding it as AnyCodable
                _ = try? proposalsContainer.decode(AnyCodable.self)
            }
        }
        proposals = parsed
    }
}
