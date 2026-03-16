import Foundation

// MARK: - API Client

/// HTTP client for communicating with the treasury26 backend API.
final class APIClient {
    static let shared = APIClient()

    // Default to the production API; override via Settings or environment
    let baseURL: URL

    private let session: URLSession
    private let decoder: JSONDecoder

    init(baseURL: URL = URL(string: "https://api.trezu.app/api")!) {
        self.baseURL = baseURL

        let config = URLSessionConfiguration.default
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.httpCookieStorage = .shared
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
    }

    // MARK: - Generic Request

    func request<T: Decodable>(
        method: String = "GET",
        path: String,
        queryItems: [URLQueryItem]? = nil,
        body: Any? = nil
    ) async throws -> T {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)!
        components.queryItems = queryItems?.isEmpty == true ? nil : queryItems

        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8)
            throw APIError.httpError(statusCode: httpResponse.statusCode, body: errorBody)
        }

        // Handle empty responses gracefully
        if data.isEmpty {
            throw APIError.emptyResponse
        }

        return try decoder.decode(T.self, from: data)
    }

    func requestOptional<T: Decodable>(
        method: String = "GET",
        path: String,
        queryItems: [URLQueryItem]? = nil,
        body: Any? = nil
    ) async -> T? {
        do {
            return try await request(method: method, path: path, queryItems: queryItems, body: body) as T
        } catch {
            // Expected for unauthenticated calls, 404s, etc.
            return nil
        }
    }

    func requestVoid(
        method: String = "POST",
        path: String,
        queryItems: [URLQueryItem]? = nil,
        body: Any? = nil
    ) async throws {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)!
        components.queryItems = queryItems?.isEmpty == true ? nil : queryItems

        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode, body: nil)
        }
    }

    // MARK: - Auth Endpoints

    func getAuthChallenge() async throws -> AuthChallenge {
        try await request(method: "POST", path: "auth/challenge")
    }

    func authLogin(
        accountId: String,
        publicKey: String,
        signature: String,
        message: String,
        nonce: String,
        recipient: String
    ) async throws -> AuthUser {
        try await request(
            method: "POST",
            path: "auth/login",
            body: [
                "accountId": accountId,
                "publicKey": publicKey,
                "signature": signature,
                "message": message,
                "nonce": nonce,
                "recipient": recipient
            ]
        )
    }

    func getAuthMe() async -> AuthUser? {
        await requestOptional(path: "auth/me")
    }

    func authLogout() async throws {
        try await requestVoid(method: "POST", path: "auth/logout")
    }

    func acceptTerms() async throws {
        try await requestVoid(method: "POST", path: "auth/accept-terms")
    }

    // MARK: - Treasury Endpoints

    func getUserTreasuries(accountId: String) async throws -> [Treasury] {
        try await request(path: "user/treasuries", queryItems: [
            URLQueryItem(name: "accountId", value: accountId)
        ])
    }

    func getTreasuryPolicy(daoId: String) async throws -> Policy {
        try await request(path: "treasury/policy", queryItems: [
            URLQueryItem(name: "treasuryId", value: daoId)
        ])
    }

    func getTreasuryConfig(daoId: String) async throws -> DaoConfig {
        try await request(path: "treasury/config", queryItems: [
            URLQueryItem(name: "treasuryId", value: daoId)
        ])
    }

    func saveTreasury(daoId: String) async throws {
        try await requestVoid(method: "POST", path: "user/treasuries/save", body: ["dao_id": daoId])
    }

    func hideTreasury(daoId: String) async throws {
        try await requestVoid(method: "POST", path: "user/treasuries/hide", body: ["dao_id": daoId])
    }

    func removeTreasury(daoId: String) async throws {
        try await requestVoid(method: "POST", path: "user/treasuries/remove", body: ["dao_id": daoId])
    }

    // MARK: - Assets & Balance Endpoints

    func getAssets(daoId: String) async throws -> [TreasuryAsset] {
        try await request(path: "user/assets", queryItems: [
            URLQueryItem(name: "accountId", value: daoId)
        ])
    }

    func getBalanceHistory(
        daoId: String,
        interval: String = "daily",
        startTime: Date? = nil,
        endTime: Date? = nil
    ) async throws -> [BalanceHistoryPoint] {
        let formatter = ISO8601DateFormatter()
        let end = endTime ?? Date()
        let start = startTime ?? Calendar.current.date(byAdding: .day, value: -30, to: end)!

        let response: ChartResponse = try await request(path: "balance-history/chart", queryItems: [
            URLQueryItem(name: "accountId", value: daoId),
            URLQueryItem(name: "interval", value: interval),
            URLQueryItem(name: "startTime", value: formatter.string(from: start)),
            URLQueryItem(name: "endTime", value: formatter.string(from: end))
        ])
        return response.snapshots
    }

    func getRecentActivity(daoId: String, limit: Int = 20) async throws -> [ActivityItem] {
        let response: RecentActivityResponse = try await request(path: "recent-activity", queryItems: [
            URLQueryItem(name: "accountId", value: daoId),
            URLQueryItem(name: "limit", value: "\(limit)")
        ])
        return response.data
    }

    // MARK: - Proposal Endpoints

    func getProposals(
        daoId: String,
        statuses: [String] = [],
        page: Int = 0,
        pageSize: Int = 15,
        search: String? = nil
    ) async throws -> PaginatedProposals {
        var items = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "page_size", value: "\(pageSize)"),
            URLQueryItem(name: "sort_by", value: "CreationTime"),
            URLQueryItem(name: "sort_direction", value: "desc")
        ]
        if !statuses.isEmpty {
            items.append(URLQueryItem(name: "statuses", value: statuses.joined(separator: ",")))
        }
        if let search = search, !search.isEmpty {
            items.append(URLQueryItem(name: "search", value: search))
        }
        return try await request(path: "proposals/\(daoId)", queryItems: items)
    }

    func getProposal(daoId: String, proposalId: Int) async throws -> Proposal {
        try await request(path: "proposal/\(daoId)/\(proposalId)")
    }

    func getProposers(daoId: String) async throws -> [String] {
        try await request(path: "proposals/\(daoId)/proposers")
    }

    func getApprovers(daoId: String) async throws -> [String] {
        try await request(path: "proposals/\(daoId)/approvers")
    }

    // MARK: - Token Endpoints

    func getTokenMetadata(tokenId: String) async throws -> TokenMetadata {
        try await request(path: "token/metadata", queryItems: [
            URLQueryItem(name: "tokenId", value: tokenId)
        ])
    }

    func getTokenBalance(accountId: String, tokenId: String, network: String) async throws -> TokenBalance {
        try await request(path: "user/balance", queryItems: [
            URLQueryItem(name: "accountId", value: accountId),
            URLQueryItem(name: "tokenId", value: tokenId),
            URLQueryItem(name: "network", value: network)
        ])
    }

    // MARK: - Profile

    func getUserProfile(accountId: String) async -> UserProfile? {
        await requestOptional(path: "user/profile", queryItems: [
            URLQueryItem(name: "account_id", value: accountId)
        ])
    }

    func checkAccountExists(accountId: String) async throws -> Bool {
        let result: [String: Bool] = try await request(path: "user/check-account-exists", queryItems: [
            URLQueryItem(name: "account_id", value: accountId)
        ])
        return result["exists"] ?? false
    }

    // MARK: - Delegate Action Relay

    func relayDelegateAction(
        signedDelegateAction: String,
        treasuryId: String,
        storageBytes: Int = 150
    ) async throws -> RelayResponse {
        try await request(
            method: "POST",
            path: "relay/delegate-action",
            body: [
                "signedDelegateAction": signedDelegateAction,
                "treasuryId": treasuryId,
                "storageBytes": "\(storageBytes)"
            ]
        )
    }
}

struct RelayResponse: Codable {
    let success: Bool
    let error: String?
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int, body: String?)
    case emptyResponse
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code, let body):
            return "HTTP \(code): \(body ?? "Unknown error")"
        case .emptyResponse:
            return "Empty response from server"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}
