import Foundation

struct RecentActivity: Codable, Identifiable, Hashable {
    let id: Int
    let blockTime: String
    let tokenId: String?
    let tokenMetadata: TokenMetadata?
    let counterparty: String?
    let signerId: String?
    let receiverId: String?
    let amount: String?
    let transactionHashes: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case blockTime = "block_time"
        case tokenId = "token_id"
        case tokenMetadata = "token_metadata"
        case counterparty
        case signerId = "signer_id"
        case receiverId = "receiver_id"
        case amount
        case transactionHashes = "transaction_hashes"
    }

    var formattedTime: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: blockTime) else {
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: blockTime) else {
                return ""
            }
            let relFormatter = RelativeDateTimeFormatter()
            relFormatter.unitsStyle = .abbreviated
            return relFormatter.localizedString(for: date, relativeTo: Date())
        }
        let relFormatter = RelativeDateTimeFormatter()
        relFormatter.unitsStyle = .abbreviated
        return relFormatter.localizedString(for: date, relativeTo: Date())
    }

    var actionDescription: String {
        if let counterparty = counterparty {
            switch counterparty {
            case "STAKING_REWARD":
                return "Staking Reward"
            default:
                return counterparty
            }
        }
        return tokenMetadata?.symbol ?? "Transfer"
    }

    var isSuccessful: Bool {
        true // Activities from this API are successful transactions
    }
}

struct TokenMetadata: Codable, Hashable {
    let tokenId: String?
    let name: String?
    let symbol: String?
    let decimals: Int?
    let icon: String?
}

struct RecentActivityResponse: Codable {
    let data: [RecentActivity]
    let total: Int?

    var activities: [RecentActivity] {
        data
    }
}
