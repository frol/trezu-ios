import Foundation

// MARK: - TreasuryAsset

struct TreasuryAsset: Codable, Identifiable {
    var id: String {
        let base = contractId ?? "near"
        if let residency { return "\(base)-\(residency.rawValue)" }
        return base
    }
    let contractId: String?
    let symbol: String
    let name: String
    let icon: String?
    let decimals: Int
    let balance: AssetBalance
    let price: String?
    let residency: TokenResidency?

    // Convenience accessors
    var tokenId: String? { contractId }

    var totalBalance: String {
        switch balance {
        case .standard(let info):
            return info.total
        case .other(_, let dict):
            // Staked/Vested balances — look for common total keys
            if let total = dict["total"]?.value as? String { return total }
            if let staked = dict["staked"]?.value as? String { return staked }
            return "0"
        }
    }

    var formattedBalance: String {
        let tokenPrice = price.flatMap { Double($0) }
        return formatTokenAmount(totalBalance, decimals: decimals, tokenPrice: tokenPrice)
    }

    var balanceUSD: Double? {
        guard let priceVal = price, let p = Double(priceVal) else { return nil }
        guard let rawBal = Double(totalBalance) else { return nil }
        let divisor = pow(10.0, Double(decimals))
        return (rawBal / divisor) * p
    }

    var formattedBalanceUSD: String {
        if let usd = balanceUSD {
            return formatCurrency(usd)
        }
        return "--"
    }
}

// Balance is an externally tagged enum: {"Standard": {"total": "...", "locked": "..."}}
// or {"Staked": {...}} or {"Vested": {...}}
enum AssetBalance: Codable {
    case standard(StandardBalance)
    case other(String, [String: AnyCodable])

    struct StandardBalance: Codable {
        let total: String
        let locked: String
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dict = try container.decode([String: AnyCodable].self)

        if let standardVal = dict["Standard"],
           let standardDict = standardVal.value as? [String: Any],
           let total = standardDict["total"] as? String,
           let locked = standardDict["locked"] as? String {
            self = .standard(StandardBalance(total: total, locked: locked))
        } else if let (key, val) = dict.first,
                  let nested = val.value as? [String: Any] {
            // Staked, Vested, etc. — extract total if available
            var strDict: [String: AnyCodable] = [:]
            for (k, v) in nested {
                strDict[k] = AnyCodable(v)
            }
            self = .other(key, strDict)
        } else {
            self = .standard(StandardBalance(total: "0", locked: "0"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .standard(let b):
            try container.encode(["Standard": b])
        case .other(let key, let dict):
            try container.encode([key: dict])
        }
    }
}

enum TokenResidency: String, Codable {
    case near = "Near"
    case ft = "Ft"
    case intents = "Intents"
    case lockup = "Lockup"
    case staked = "Staked"
}

// MARK: - TokenMetadata

struct TokenMetadata: Codable, Identifiable {
    var id: String { tokenId ?? "near" }
    let tokenId: String?
    let symbol: String
    let name: String
    let icon: String?
    let decimals: Int
    let price: Double?
    let network: String?
    let chainName: String?
    let chainIcons: ChainIcons?

    enum CodingKeys: String, CodingKey {
        case tokenId = "token_id"
        case symbol, name, icon, decimals, price, network
        case chainName = "chain_name"
        case chainIcons = "chain_icons"
    }
}

struct ChainIcons: Codable {
    let dark: String?
    let light: String?
}

// MARK: - Balance History

// The chart endpoint returns { "<tokenId>": [BalanceSnapshot...], "lastSyncedAt": "..." }
// where the token arrays are flattened into the top-level object.
struct BalanceHistoryPoint: Codable, Identifiable {
    var id: String { timestamp }
    let timestamp: String
    let balance: Double?
    let priceUsd: Double?
    let valueUsd: Double?

    var totalBalanceUsd: Double { valueUsd ?? 0 }

    var date: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: timestamp) ?? ISO8601DateFormatter().date(from: timestamp)
    }
}

// Wrapper for chart response — flattened HashMap<String, Vec<BalanceSnapshot>> + lastSyncedAt
struct ChartResponse: Codable {
    let snapshots: [BalanceHistoryPoint]
    let lastSyncedAt: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        var allSnapshots: [BalanceHistoryPoint] = []
        var syncedAt: String?

        for key in container.allKeys {
            if key.stringValue == "lastSyncedAt" {
                syncedAt = try? container.decode(String.self, forKey: key)
            } else {
                if let points = try? container.decode([BalanceHistoryPoint].self, forKey: key) {
                    allSnapshots.append(contentsOf: points)
                }
            }
        }

        // Sort by timestamp
        self.snapshots = allSnapshots.sorted { $0.timestamp < $1.timestamp }
        self.lastSyncedAt = syncedAt
    }

    func encode(to encoder: Encoder) throws {
        // Not needed for API consumption
    }
}

private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { self.stringValue = String(intValue); self.intValue = intValue }
}

// MARK: - Recent Activity

// Response wrapper: { "data": [...], "total": N }
struct RecentActivityResponse: Codable {
    let data: [ActivityItem]
    let total: Int
}

// Backend RecentActivity uses camelCase (rename_all = "camelCase")
struct ActivityItem: Codable, Identifiable {
    var id: String { "\(activityId)" }

    let activityId: Int
    let blockTime: String
    let tokenId: String
    let tokenMetadata: ActivityTokenMetadata?
    let counterparty: String?
    let signerId: String?
    let receiverId: String?
    let amount: String?
    let transactionHashes: [String]?
    let valueUsd: Double?
    let actionKind: String?
    let methodName: String?

    // Use manual CodingKeys since the backend field is "id" but we rename to activityId
    enum CodingKeys: String, CodingKey {
        case activityId = "id"
        case blockTime, tokenId, tokenMetadata, counterparty
        case signerId, receiverId, amount, transactionHashes
        case valueUsd, actionKind, methodName
    }

    var isIncoming: Bool {
        // Determine direction based on action kind or amount sign
        if let kind = actionKind {
            return kind.contains("receive") || kind.contains("deposit")
        }
        return false
    }

    var tokenSymbol: String { tokenMetadata?.symbol ?? "" }
    var tokenDecimals: Int { tokenMetadata?.decimals ?? 0 }

    var formattedAmount: String {
        guard let amount = amount else { return "--" }
        let prefix = isIncoming ? "+" : "-"
        return "\(prefix)\(formatTokenAmount(amount, decimals: tokenDecimals)) \(tokenSymbol)"
    }

    var activityDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: blockTime) ?? ISO8601DateFormatter().date(from: blockTime)
    }
}

struct ActivityTokenMetadata: Codable {
    let symbol: String?
    let name: String?
    let icon: String?
    let decimals: Int?
}

// MARK: - Formatting Helpers

/// Formats a raw token amount with price-aware precision.
/// Shows enough decimal places so the smallest visible increment represents ~$0.01.
/// Falls back to a sensible default when price is unavailable.
func formatTokenAmount(_ raw: String, decimals: Int, tokenPrice: Double? = nil) -> String {
    guard let rawDecimal = Decimal(string: raw) else { return raw }
    let divisor = pow(Decimal(10), decimals)
    let value = rawDecimal / divisor

    guard value > 0 else { return "0" }

    let displayDecimals: Int
    if let price = tokenPrice, price > 0 {
        // Calculate decimals needed to represent $0.01:
        // requiredPrecision = 0.01 / price
        // decimalsNeeded = ceil(-log10(requiredPrecision))
        let requiredPrecision = 0.01 / price
        let log10Value = log10(requiredPrecision)
        displayDecimals = min(max(0, Int(ceil(-log10Value))), decimals)
    } else {
        // Fallback: 2 decimals for values >= 1, up to 4 for smaller values
        let doubleValue = NSDecimalNumber(decimal: value).doubleValue
        if doubleValue >= 1.0 {
            displayDecimals = 2
        } else if doubleValue >= 0.01 {
            displayDecimals = 4
        } else {
            // For very small values, show enough digits to see something meaningful
            let magnitude = doubleValue > 0 ? Int(ceil(-log10(doubleValue))) + 2 : 6
            displayDecimals = min(magnitude, decimals)
        }
    }

    // Truncate (don't round up) to the desired precision
    let multiplier = pow(Decimal(10), displayDecimals)
    let scaledValue = NSDecimalNumber(decimal: value * multiplier)
    let flooredScaled = scaledValue.rounding(
        accordingToBehavior: NSDecimalNumberHandler(
            roundingMode: .down,
            scale: 0,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )
    )
    let finalValue = flooredScaled.dividing(by: NSDecimalNumber(decimal: multiplier))

    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = displayDecimals
    formatter.minimumFractionDigits = 0
    formatter.roundingMode = .down

    let result = formatter.string(from: finalValue) ?? "\(finalValue)"
    // Remove trailing zeros after decimal point
    if result.contains(".") {
        let cleaned = result.replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
        return cleaned.hasSuffix(".") ? String(cleaned.dropLast()) : cleaned
    }
    return result
}

/// Formats a decimal amount string (already in human-readable form, not raw integer) with price-aware precision.
/// Use this for exchange amounts where the value is already a decimal like "1.003948" rather than a raw "1003948000000".
func formatDecimalAmount(_ amount: String, tokenPrice: Double? = nil) -> String {
    guard let value = Decimal(string: amount), value > 0 else { return amount }

    let displayDecimals: Int
    if let price = tokenPrice, price > 0 {
        let requiredPrecision = 0.01 / price
        let log10Value = log10(requiredPrecision)
        displayDecimals = max(0, Int(ceil(-log10Value)))
    } else {
        let doubleValue = NSDecimalNumber(decimal: value).doubleValue
        if doubleValue >= 1.0 {
            displayDecimals = 2
        } else if doubleValue >= 0.01 {
            displayDecimals = 4
        } else {
            let magnitude = doubleValue > 0 ? Int(ceil(-log10(doubleValue))) + 2 : 6
            displayDecimals = magnitude
        }
    }

    // Truncate (don't round up)
    let multiplier = pow(Decimal(10), displayDecimals)
    let scaledValue = NSDecimalNumber(decimal: value * multiplier)
    let flooredScaled = scaledValue.rounding(
        accordingToBehavior: NSDecimalNumberHandler(
            roundingMode: .down,
            scale: 0,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )
    )
    let finalValue = flooredScaled.dividing(by: NSDecimalNumber(decimal: multiplier))

    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = displayDecimals
    formatter.minimumFractionDigits = 0
    formatter.roundingMode = .down

    let result = formatter.string(from: finalValue) ?? "\(finalValue)"
    if result.contains(".") {
        let cleaned = result.replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
        return cleaned.hasSuffix(".") ? String(cleaned.dropLast()) : cleaned
    }
    return result
}

func formatCurrency(_ value: Double) -> String {
    value.formatted(.currency(code: "USD"))
}

func formatNEAR(_ yocto: String) -> String {
    formatTokenAmount(yocto, decimals: 24)
}
