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

    /// The display name for the proposal kind, using full UI classification.
    var displayKind: String {
        uiKind.rawValue
    }

    /// The icon for the proposal kind, using full UI classification.
    var displayIcon: String {
        uiKind.iconName
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

    // MARK: - Client-side Expiration Detection

    /// Exchange proposals expire after 24 hours.
    private static let exchangeExpiryNanos: Double = 24 * 60 * 60 * 1_000_000_000

    /// Determines the effective UI status, accounting for client-side expiration detection.
    /// The blockchain status may still be `InProgress` even after the proposal period has elapsed,
    /// because expiration is only finalized on-chain when someone interacts with the contract.
    func effectiveStatus(proposalPeriod: String?) -> ProposalStatus {
        guard status == .inProgress else { return status }
        guard let submissionTime, let submissionNanos = Double(submissionTime) else { return status }

        let nowNanos = Date.now.timeIntervalSince1970 * 1_000_000_000

        // Exchange proposals have a fixed 24-hour expiry
        if isExchange {
            if submissionNanos + Self.exchangeExpiryNanos < nowNanos {
                return .expired
            }
        }

        // Other proposals use the policy's proposal_period
        if let periodStr = proposalPeriod, let periodNanos = Double(periodStr) {
            if submissionNanos + periodNanos < nowNanos {
                return .expired
            }
        }

        return .inProgress
    }

    /// Required funds for this proposal — returns (tokenId, amount) if applicable.
    var requiredFunds: (tokenId: String, amount: String)? {
        switch kind {
        case .transfer(let action):
            let tokenId = action.tokenId ?? "near"
            return (tokenId: tokenId.isEmpty ? "near" : tokenId, amount: action.amount)
        case .functionCall(let fc):
            return extractFunctionCallRequiredFunds(fc)
        default:
            return nil
        }
    }

    private func extractFunctionCallRequiredFunds(_ fc: FunctionCallAction) -> (tokenId: String, amount: String)? {
        // near_withdraw (wrap.near unwrap)
        if let action = fc.actions.first(where: { $0.methodName == "near_withdraw" }),
           fc.receiverId == "wrap.near" {
            if let args = action.decodedArgs, let amount = args["amount"] as? String {
                return (tokenId: "wrap.near", amount: amount)
            }
        }

        // near_deposit (wrap.near wrap) — uses deposit amount
        if let action = fc.actions.first(where: { $0.methodName == "near_deposit" }),
           fc.receiverId == "wrap.near" {
            if !action.deposit.isEmpty, action.deposit != "0" {
                return (tokenId: "near", amount: action.deposit)
            }
        }

        // ft_transfer / ft_transfer_call
        if let action = fc.actions.first(where: { $0.methodName == "ft_transfer" || $0.methodName == "ft_transfer_call" }) {
            if let args = action.decodedArgs {
                let amount = args["amount"] as? String ?? "0"
                if action.methodName == "ft_transfer" {
                    return (tokenId: fc.receiverId, amount: amount)
                }
                // ft_transfer_call — check if batch payment
                if let receiverId = args["receiver_id"] as? String,
                   receiverId == bulkPaymentContractId {
                    return (tokenId: fc.receiverId, amount: amount)
                }
                return (tokenId: fc.receiverId, amount: amount)
            }
        }

        // ft_withdraw (Intents withdrawal)
        if let action = fc.actions.first(where: { $0.methodName == "ft_withdraw" }) {
            if let args = action.decodedArgs,
               let amount = args["amount"] as? String,
               let token = args["token"] as? String {
                return (tokenId: "nep141:\(token)", amount: amount)
            }
        }

        // mt_transfer / mt_transfer_call
        if let action = fc.actions.first(where: { $0.methodName == "mt_transfer" || $0.methodName == "mt_transfer_call" }) {
            if let args = action.decodedArgs {
                let amount = args["amount"] as? String ?? "0"
                let tokenId = args["token_id"] as? String ?? fc.receiverId
                if let receiverId = args["receiver_id"] as? String,
                   receiverId == bulkPaymentContractId {
                    return (tokenId: tokenId, amount: amount)
                }
                return (tokenId: tokenId, amount: amount)
            }
        }

        // approve_list (NEAR batch payment via bulkpayment.near)
        if fc.receiverId == bulkPaymentContractId,
           let action = fc.actions.first(where: { $0.methodName == "approve_list" }) {
            if !action.deposit.isEmpty, action.deposit != "0" {
                return (tokenId: "near", amount: action.deposit)
            }
        }

        // Staking proposals (deposit_and_stake, deposit)
        if let action = fc.actions.first(where: { $0.methodName == "deposit_and_stake" || $0.methodName == "deposit" }) {
            if let args = action.decodedArgs, let amount = args["amount"] as? String {
                return (tokenId: "near", amount: amount)
            }
            if !action.deposit.isEmpty, action.deposit != "0" {
                return (tokenId: "near", amount: action.deposit)
            }
        }

        // Vesting proposal (create on lockup.near with NEAR deposit)
        if let action = fc.actions.first(where: { $0.methodName == "create" }),
           fc.receiverId.contains("lockup.near") {
            if !action.deposit.isEmpty, action.deposit != "0" {
                return (tokenId: "near", amount: action.deposit)
            }
        }

        return nil
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
    var isTerminal: Bool { self != .inProgress }
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

// MARK: - Proposal UI Kind

/// The user-facing classification of a proposal, matching the frontend's display names.
enum ProposalUIKind: String {
    case paymentRequest = "Payment Request"
    case batchPaymentRequest = "Batch Payment Request"
    case exchange = "Exchange"
    case functionCall = "Function Call"
    case earnNEAR = "Earn NEAR"
    case unstakeNEAR = "Unstake NEAR"
    case withdrawEarnings = "Withdraw Earnings"
    case vesting = "Vesting"
    case changePolicy = "Change Policy"
    case updateSettings = "Update General Settings"
    case upgrade = "Upgrade"
    case addMember = "Add Member"
    case removeMember = "Remove Member"
    case setStaking = "Set Staking Contract"
    case bounty = "Bounty"
    case vote = "Vote"
    case unsupported = "Unsupported"

    var iconName: String {
        switch self {
        case .paymentRequest: return "arrow.right.circle"
        case .batchPaymentRequest: return "arrow.right.arrow.left.circle"
        case .exchange: return "arrow.triangle.swap"
        case .functionCall: return "terminal"
        case .earnNEAR: return "chart.line.uptrend.xyaxis"
        case .unstakeNEAR: return "arrow.down.circle"
        case .withdrawEarnings: return "banknote"
        case .vesting: return "calendar.badge.clock"
        case .changePolicy: return "shield.checkered"
        case .updateSettings: return "gearshape"
        case .upgrade: return "arrow.up.circle"
        case .addMember: return "person.badge.plus"
        case .removeMember: return "person.badge.minus"
        case .setStaking: return "lock.circle"
        case .bounty: return "gift"
        case .vote: return "hand.thumbsup"
        case .unsupported: return "questionmark.circle"
        }
    }
}

let bulkPaymentContractId = "bulkpayment.near"

extension Proposal {
    /// Determines the UI classification of this proposal, matching the frontend's `getProposalUIKind`.
    var uiKind: ProposalUIKind {
        if isExchange { return .exchange }

        switch kind {
        case .transfer:
            return .paymentRequest
        case .functionCall(let fc):
            if isVestingProposal(fc) { return .vesting }
            if let ftResult = classifyFTTransfer(fc) { return ftResult }
            if isBatchPayment(fc) { return .batchPaymentRequest }
            if let mtResult = classifyMTTransfer(fc) { return mtResult }
            if let staking = classifyStaking(fc) { return staking }
            return .functionCall
        case .addMemberToRole:
            return .addMember
        case .removeMemberFromRole:
            return .removeMember
        case .changePolicy:
            return .changePolicy
        case .changeConfig:
            return .updateSettings
        case .upgradeSelf, .upgradeRemote:
            return .upgrade
        case .setStakingContract:
            return .setStaking
        case .addBounty, .bountyDone:
            return .bounty
        case .vote:
            return .vote
        case .factoryInfoUpdate, .unknown:
            return .unsupported
        }
    }

    // MARK: - FunctionCall Sub-type Detection

    private func isVestingProposal(_ fc: FunctionCallAction) -> Bool {
        let receiver = fc.receiverId
        let isLockup = receiver.contains("lockup.near") || receiver == "lockup.near"
        return isLockup && fc.actions.first?.methodName == "create"
    }

    private func classifyFTTransfer(_ fc: FunctionCallAction) -> ProposalUIKind? {
        // Intent withdraw or lockup transfer → Payment Request
        if isIntentWithdrawProposal(fc) || isLockupTransferProposal(fc) {
            return .paymentRequest
        }

        // Exchange detection via description
        if decodedDescription.fields["proposalAction"] == "asset-exchange" {
            return .exchange
        }

        // wrap.near near_withdraw/near_deposit → Exchange
        if fc.receiverId == "wrap.near" &&
            fc.actions.contains(where: { $0.methodName == "near_withdraw" || $0.methodName == "near_deposit" }) {
            return .exchange
        }

        // ft_transfer / ft_transfer_call
        guard let action = fc.actions.first(where: { $0.methodName == "ft_transfer" || $0.methodName == "ft_transfer_call" }) else {
            return nil
        }

        if action.methodName == "ft_transfer" {
            return .paymentRequest
        }

        // ft_transfer_call — check if receiver_id in args is bulk payment contract
        if let args = action.decodedArgs,
           let receiverId = args["receiver_id"] as? String,
           receiverId == bulkPaymentContractId {
            return .batchPaymentRequest
        }

        return .paymentRequest
    }

    private func classifyMTTransfer(_ fc: FunctionCallAction) -> ProposalUIKind? {
        guard let transfer = fc.actions.first(where: { $0.methodName == "mt_transfer" || $0.methodName == "mt_transfer_call" }) else {
            return nil
        }
        if let args = transfer.decodedArgs,
           let receiverId = args["receiver_id"] as? String,
           receiverId == bulkPaymentContractId {
            return .batchPaymentRequest
        }
        return .exchange
    }

    private func isBatchPayment(_ fc: FunctionCallAction) -> Bool {
        // Direct call to bulk payment contract with approve_list
        if fc.receiverId == bulkPaymentContractId {
            if fc.actions.contains(where: { $0.methodName == "approve_list" }) {
                return true
            }
        }

        // ft_transfer_call or mt_transfer_call with receiver_id = bulkpayment.near
        for action in fc.actions {
            if action.methodName == "ft_transfer_call" || action.methodName == "mt_transfer_call" {
                if let args = action.decodedArgs,
                   let receiverId = args["receiver_id"] as? String,
                   receiverId == bulkPaymentContractId {
                    return true
                }
            }
        }

        return false
    }

    private func classifyStaking(_ fc: FunctionCallAction) -> ProposalUIKind? {
        let receiver = fc.receiverId
        let isPool = receiver.hasSuffix("poolv1.near") || receiver.hasSuffix("lockup.near")
        guard isPool else { return nil }

        let stakeMethods: Set<String> = ["stake", "deposit_and_stake", "deposit"]
        let withdrawMethods: Set<String> = ["withdraw", "withdraw_all", "withdraw_all_from_staking_pool"]
        let unstakeMethods: Set<String> = ["unstake"]

        if fc.actions.contains(where: { stakeMethods.contains($0.methodName) }) {
            return .earnNEAR
        }
        if fc.actions.contains(where: { withdrawMethods.contains($0.methodName) }) {
            return .withdrawEarnings
        }
        if fc.actions.contains(where: { unstakeMethods.contains($0.methodName) }) {
            return .unstakeNEAR
        }

        return nil
    }

    private func isIntentWithdrawProposal(_ fc: FunctionCallAction) -> Bool {
        fc.actions.contains(where: { $0.methodName == "ft_withdraw" })
    }

    private func isLockupTransferProposal(_ fc: FunctionCallAction) -> Bool {
        fc.receiverId.hasSuffix(".lockup.near") &&
        fc.actions.contains(where: { $0.methodName == "transfer" })
    }
}

// MARK: - Resolved Proposal Data

/// Extracted payment/transfer data from a proposal, with token metadata resolved.
struct ResolvedProposalData {
    let tokenId: String        // "near" or contract ID
    let amount: String         // Raw amount in smallest units
    let receiver: String       // Recipient account ID
    var tokenSymbol: String = ""
    var tokenDecimals: Int = 0
    var tokenIcon: String?
    var tokenPrice: Double?
    var tokenNetwork: String?
    var tokenChainIcon: String?

    /// Batch payment data, if this is a batch payment proposal.
    var batchPaymentId: String?

    var formattedAmount: String {
        guard !amount.isEmpty, amount != "0" else { return "0" }
        return formatTokenAmount(amount, decimals: tokenDecimals, tokenPrice: tokenPrice)
    }

    var formattedUSD: String? {
        guard let price = tokenPrice, price > 0 else { return nil }
        guard let rawDecimal = Decimal(string: amount) else { return nil }
        let divisor = pow(Decimal(10), tokenDecimals)
        let tokenAmount = NSDecimalNumber(decimal: rawDecimal / divisor).doubleValue
        let usdValue = tokenAmount * price
        guard usdValue > 0.005 else { return nil } // Skip negligible values
        return formatCurrency(usdValue)
    }
}

/// Batch payment list fetched from the API.
struct BatchPaymentResponse: Codable {
    let tokenId: String?
    let submitter: String?
    let status: String?
    var payments: [BatchPayment]?

    enum CodingKeys: String, CodingKey {
        case tokenId = "token_id"
        case submitter, status, payments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tokenId = try container.decodeIfPresent(String.self, forKey: .tokenId)
        submitter = try container.decodeIfPresent(String.self, forKey: .submitter)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        var decoded = try container.decodeIfPresent([BatchPayment].self, forKey: .payments)
        // Assign stable indices as IDs
        if decoded != nil {
            for i in decoded!.indices {
                decoded![i].id = i
            }
        }
        payments = decoded
    }
}

struct BatchPayment: Codable, Identifiable {
    /// Stable identity based on index, assigned after decoding.
    var id: Int = 0
    let recipient: String
    let amount: String

    /// Payment status is a polymorphic value from the contract (e.g. "Pending" or {"Paid":{"block_height":...}}).
    /// We decode it as a raw JSON value and extract a display string.
    let status: BatchPaymentStatus?

    enum CodingKeys: String, CodingKey {
        case recipient, amount, status
    }
}

/// Handles the polymorphic `status` field in batch payments.
/// Can be a plain string like `"Pending"` or an object like `{"Paid":{"block_height":123}}`.
enum BatchPaymentStatus: Codable {
    case string(String)
    case object(String) // The top-level key, e.g. "Paid"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self = .string(str)
        } else if let dict = try? container.decode([String: AnyCodable].self),
                  let key = dict.keys.first {
            self = .object(key)
        } else {
            self = .string("Unknown")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let str): try container.encode(str)
        case .object(let key): try container.encode(key)
        }
    }

    var displayValue: String {
        switch self {
        case .string(let s): return s
        case .object(let key): return key
        }
    }
}

extension Proposal {
    /// Extracts raw payment data from the proposal kind, before token metadata resolution.
    func extractPaymentData() -> ResolvedProposalData? {
        switch kind {
        case .transfer(let action):
            let tokenId = action.tokenId ?? ""
            let isNEAR = tokenId.isEmpty
            return ResolvedProposalData(
                tokenId: isNEAR ? "near" : tokenId,
                amount: action.amount,
                receiver: action.receiverId,
                tokenSymbol: isNEAR ? "NEAR" : "",
                tokenDecimals: isNEAR ? 24 : 0
            )

        case .functionCall(let fc):
            return extractFunctionCallPaymentData(fc)

        default:
            return nil
        }
    }

    /// Extracts batch payment data (batchId, tokenId, totalAmount) for batch payment proposals.
    func extractBatchPaymentData() -> (batchId: String, tokenId: String, totalAmount: String)? {
        guard case .functionCall(let fc) = kind, uiKind == .batchPaymentRequest else { return nil }

        // approve_list (NEAR batch payment)
        if let action = fc.actions.first(where: { $0.methodName == "approve_list" }) {
            let args = action.decodedArgs
            let listId = args?["list_id"] as? String ?? ""
            return (batchId: listId, tokenId: "near", totalAmount: action.deposit)
        }

        // ft_transfer_call
        if let action = fc.actions.first(where: { $0.methodName == "ft_transfer_call" }) {
            if let args = action.decodedArgs {
                let batchId = args["msg"] as? String ?? ""
                let amount = args["amount"] as? String ?? "0"
                return (batchId: batchId, tokenId: fc.receiverId, totalAmount: amount)
            }
        }

        // mt_transfer_call
        if let action = fc.actions.first(where: { $0.methodName == "mt_transfer_call" }) {
            if let args = action.decodedArgs {
                let batchId = args["msg"] as? String ?? ""
                let amount = args["amount"] as? String ?? "0"
                let tokenId = args["token_id"] as? String ?? fc.receiverId
                return (batchId: batchId, tokenId: tokenId, totalAmount: amount)
            }
        }

        return nil
    }

    private func extractFunctionCallPaymentData(_ fc: FunctionCallAction) -> ResolvedProposalData? {
        // ft_transfer / ft_transfer_call / transfer
        if let action = fc.actions.first(where: {
            $0.methodName == "ft_transfer" ||
            $0.methodName == "ft_transfer_call" ||
            $0.methodName == "transfer"
        }) {
            // "transfer" method only counts for lockup contracts
            if action.methodName == "transfer" && !fc.receiverId.hasSuffix(".lockup.near") {
                return nil
            }

            if let args = action.decodedArgs {
                let tokenId = action.methodName == "transfer"
                    ? "near"
                    : fc.receiverId
                let isNEAR = tokenId == "near"
                return ResolvedProposalData(
                    tokenId: tokenId,
                    amount: args["amount"] as? String ?? "0",
                    receiver: args["receiver_id"] as? String ?? "",
                    tokenSymbol: isNEAR ? "NEAR" : "",
                    tokenDecimals: isNEAR ? 24 : 0
                )
            }
        }

        // ft_withdraw (Intents)
        if let action = fc.actions.first(where: { $0.methodName == "ft_withdraw" }) {
            if let args = action.decodedArgs {
                let token = args["token"] as? String ?? ""
                let receiverId = args["receiver_id"] as? String ?? ""
                let memo = args["memo"] as? String ?? ""
                let isExternalWithdraw = receiverId == token && memo.hasPrefix("WITHDRAW_TO:")
                let receiver = isExternalWithdraw
                    ? String(memo.dropFirst("WITHDRAW_TO:".count))
                    : receiverId

                return ResolvedProposalData(
                    tokenId: "nep141:\(token)",
                    amount: args["amount"] as? String ?? "0",
                    receiver: receiver
                )
            }
        }

        // Staking proposals — amount is NEAR
        let uiKind = self.uiKind
        if uiKind == .earnNEAR || uiKind == .unstakeNEAR || uiKind == .withdrawEarnings {
            let stakingAction = fc.actions.first(where: {
                ["stake", "deposit_and_stake", "deposit", "withdraw", "withdraw_all",
                 "withdraw_all_from_staking_pool", "unstake"].contains($0.methodName)
            })
            let amount: String
            if let args = stakingAction?.decodedArgs, let amt = args["amount"] as? String {
                amount = amt
            } else if let deposit = stakingAction.map({ $0.deposit }), deposit != "0" {
                amount = deposit
            } else {
                amount = decodedDescription.fields["amount"] ?? "0"
            }

            return ResolvedProposalData(
                tokenId: "near",
                amount: amount,
                receiver: fc.receiverId,
                tokenSymbol: "NEAR",
                tokenDecimals: 24
            )
        }

        // approve_list (NEAR batch payment)
        if fc.receiverId == bulkPaymentContractId,
           let action = fc.actions.first(where: { $0.methodName == "approve_list" }) {
            return ResolvedProposalData(
                tokenId: "near",
                amount: action.deposit,
                receiver: bulkPaymentContractId,
                tokenSymbol: "NEAR",
                tokenDecimals: 24
            )
        }

        return nil
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
