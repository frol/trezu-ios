import Foundation

enum APIEndpoint {
    static let baseURL = "https://near-treasury-backend.onrender.com/api"

    case userTreasuries(accountId: String)
    case userAssets(accountId: String)
    case treasuryAssets(treasuryId: String)
    case proposals(daoId: String, filters: ProposalFilters?)
    case proposal(daoId: String, proposalId: Int)
    case treasuryPolicy(treasuryId: String)
    case treasuryConfig(treasuryId: String)
    case recentActivity(accountId: String, limit: Int, offset: Int)
    case userProfile(accountId: String)

    var path: String {
        switch self {
        case .userTreasuries:
            return "/user/treasuries"
        case .userAssets:
            return "/user/assets"
        case .treasuryAssets:
            return "/treasury/assets"
        case .proposals(let daoId, _):
            return "/proposals/\(daoId)"
        case .proposal(let daoId, let proposalId):
            return "/proposal/\(daoId)/\(proposalId)"
        case .treasuryPolicy:
            return "/treasury/policy"
        case .treasuryConfig:
            return "/treasury/config"
        case .recentActivity:
            return "/recent-activity"
        case .userProfile:
            return "/user/profile"
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .userTreasuries(let accountId):
            return [URLQueryItem(name: "accountId", value: accountId)]
        case .userAssets(let accountId):
            return [URLQueryItem(name: "accountId", value: accountId)]
        case .treasuryAssets(let treasuryId):
            return [URLQueryItem(name: "treasuryId", value: treasuryId)]
        case .proposals(_, let filters):
            return filters?.queryItems ?? []
        case .proposal:
            return []
        case .treasuryPolicy(let treasuryId):
            return [URLQueryItem(name: "treasuryId", value: treasuryId)]
        case .treasuryConfig(let treasuryId):
            return [URLQueryItem(name: "treasuryId", value: treasuryId)]
        case .recentActivity(let accountId, let limit, let offset):
            return [
                URLQueryItem(name: "account_id", value: accountId),
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "offset", value: String(offset))
            ]
        case .userProfile(let accountId):
            return [URLQueryItem(name: "accountId", value: accountId)]
        }
    }

    var url: URL? {
        var components = URLComponents(string: APIEndpoint.baseURL + path)
        let items = queryItems
        if !items.isEmpty {
            components?.queryItems = items
        }
        return components?.url
    }
}
