import Foundation

struct Treasury: Codable, Identifiable, Hashable {
    let daoId: String
    let config: TreasuryConfig?

    var id: String { daoId }

    var displayName: String {
        config?.name ?? daoId
    }
}

struct TreasuryConfig: Codable, Hashable {
    let name: String?
    let purpose: String?
    let metadata: TreasuryMetadata?

    var displayName: String {
        name ?? "Treasury"
    }
}

struct TreasuryMetadata: Codable, Hashable {
    let displayName: String?
    let flagCover: String?
    let flagLogo: String?
    let primaryColor: String?
    let links: [String]?
    let legal: LegalInfo?

    // More flexible decoding - treat missing keys as nil
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        flagCover = try container.decodeIfPresent(String.self, forKey: .flagCover)
        flagLogo = try container.decodeIfPresent(String.self, forKey: .flagLogo)
        primaryColor = try container.decodeIfPresent(String.self, forKey: .primaryColor)
        links = try container.decodeIfPresent([String].self, forKey: .links)
        legal = try container.decodeIfPresent(LegalInfo.self, forKey: .legal)
    }

    enum CodingKeys: String, CodingKey {
        case displayName
        case flagCover
        case flagLogo
        case primaryColor
        case links
        case legal
    }
}

struct LegalInfo: Codable, Hashable {
    let legalStatus: String?
    let legalLink: String?
}

struct TreasuryListResponse: Codable {
    let treasuries: [Treasury]
}

struct TreasurySummary: Codable, Identifiable, Hashable {
    let daoId: String
    let name: String
    let lastAccessed: Date

    var id: String { daoId }
}
