import Foundation

enum TokenResidency: String, Codable {
    case near = "Near"
    case ft = "Ft"
    case intents = "Intents"
    case aurora = "aurora"
    case base = "base"
    case ethereum = "ethereum"
    case arbitrum = "arbitrum"
    case solana = "solana"
    case bitcoin = "bitcoin"
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = TokenResidency(rawValue: rawValue) ?? TokenResidency(rawValue: rawValue.lowercased()) ?? .unknown
    }
}

struct TreasuryAsset: Codable, Identifiable, Hashable {
    let id: String
    let contractId: String?
    let residency: TokenResidency
    let symbol: String
    let balance: String
    let decimals: Int
    let price: Double?
    let name: String
    let icon: String?
    let network: String?
    let chainName: String?
    let lockedBalance: String?

    enum CodingKeys: String, CodingKey {
        case id
        case contractId
        case residency
        case symbol
        case balance
        case decimals
        case price
        case name
        case icon
        case network
        case chainName
        case lockedBalance
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        contractId = try container.decodeIfPresent(String.self, forKey: .contractId)
        residency = try container.decode(TokenResidency.self, forKey: .residency)
        symbol = try container.decode(String.self, forKey: .symbol)
        balance = try container.decode(String.self, forKey: .balance)
        decimals = try container.decode(Int.self, forKey: .decimals)
        name = try container.decode(String.self, forKey: .name)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        network = try container.decodeIfPresent(String.self, forKey: .network)
        chainName = try container.decodeIfPresent(String.self, forKey: .chainName)
        lockedBalance = try container.decodeIfPresent(String.self, forKey: .lockedBalance)

        // Price can be a Double or a String
        if let priceDouble = try? container.decode(Double.self, forKey: .price) {
            price = priceDouble
        } else if let priceString = try? container.decode(String.self, forKey: .price),
                  let priceDouble = Double(priceString) {
            price = priceDouble
        } else {
            price = nil
        }
    }

    var balanceUSD: Double {
        let balanceValue = Double(balance) ?? 0
        let actualBalance = balanceValue / pow(10, Double(decimals))
        return actualBalance * (price ?? 0)
    }

    var formattedBalance: String {
        let balanceValue = Double(balance) ?? 0
        let actualBalance = balanceValue / pow(10, Double(decimals))

        if actualBalance >= 1_000_000 {
            return String(format: "%.2fM", actualBalance / 1_000_000)
        } else if actualBalance >= 1_000 {
            return String(format: "%.2fK", actualBalance / 1_000)
        } else if actualBalance >= 1 {
            return String(format: "%.4f", actualBalance)
        } else {
            return String(format: "%.6f", actualBalance)
        }
    }

    var formattedBalanceUSD: String {
        if balanceUSD >= 1_000_000 {
            return String(format: "$%.2fM", balanceUSD / 1_000_000)
        } else if balanceUSD >= 1_000 {
            return String(format: "$%.2fK", balanceUSD / 1_000)
        } else {
            return String(format: "$%.2f", balanceUSD)
        }
    }

    // For previews and testing
    init(id: String, contractId: String?, residency: TokenResidency, symbol: String, balance: String, decimals: Int, price: Double?, name: String, icon: String?, balanceUSD: Double = 0) {
        self.id = id
        self.contractId = contractId
        self.residency = residency
        self.symbol = symbol
        self.balance = balance
        self.decimals = decimals
        self.price = price
        self.name = name
        self.icon = icon
        self.network = nil
        self.chainName = nil
        self.lockedBalance = nil
    }
}

struct TreasuryAssetsResponse {
    let assets: [TreasuryAsset]

    init(assets: [TreasuryAsset]) {
        self.assets = assets
    }

    var totalBalanceUSD: Double {
        assets.reduce(0) { $0 + $1.balanceUSD }
    }

    var formattedTotalBalanceUSD: String {
        if totalBalanceUSD >= 1_000_000 {
            return String(format: "$%.2fM", totalBalanceUSD / 1_000_000)
        } else if totalBalanceUSD >= 1_000 {
            return String(format: "$%.2fK", totalBalanceUSD / 1_000)
        } else {
            return String(format: "$%.2f", totalBalanceUSD)
        }
    }
}
