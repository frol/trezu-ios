import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code, let message):
            return "HTTP Error \(code): \(message ?? "Unknown error")"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

@Observable
final class TreasuryAPIClient {
    static let shared = TreasuryAPIClient()

    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
    }

    // MARK: - Generic Request

    private func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        guard let url = endpoint.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let message = String(data: data, encoding: .utf8)
                throw APIError.httpError(statusCode: httpResponse.statusCode, message: message)
            }

            do {
                return try decoder.decode(T.self, from: data)
            } catch let decodingError as DecodingError {
                // Print detailed error for debugging
                print("Decoding error for \(T.self):")
                print("  Error: \(decodingError)")
                if let dataString = String(data: data.prefix(500), encoding: .utf8) {
                    print("  Response preview: \(dataString)")
                }
                throw APIError.decodingError(decodingError)
            } catch {
                throw APIError.decodingError(error)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    // MARK: - Treasury Endpoints

    func getUserTreasuries(accountId: String) async throws -> [Treasury] {
        // API returns array directly, not wrapped
        try await request(.userTreasuries(accountId: accountId))
    }

    func getTreasuryAssets(treasuryId: String) async throws -> TreasuryAssetsResponse {
        // Assets API returns an array directly
        let assets: [TreasuryAsset] = try await request(.treasuryAssets(treasuryId: treasuryId))
        return TreasuryAssetsResponse(assets: assets)
    }

    func getUserAssets(accountId: String) async throws -> TreasuryAssetsResponse {
        // Assets API returns an array directly
        let assets: [TreasuryAsset] = try await request(.userAssets(accountId: accountId))
        return TreasuryAssetsResponse(assets: assets)
    }

    // MARK: - Proposal Endpoints

    func getProposals(daoId: String, filters: ProposalFilters? = nil) async throws -> ProposalsResponse {
        try await request(.proposals(daoId: daoId, filters: filters))
    }

    func getProposal(daoId: String, proposalId: Int) async throws -> Proposal {
        try await request(.proposal(daoId: daoId, proposalId: proposalId))
    }

    // MARK: - Policy Endpoints

    func getTreasuryPolicy(treasuryId: String) async throws -> Policy {
        // Policy API returns the policy directly
        try await request(.treasuryPolicy(treasuryId: treasuryId))
    }

    func getTreasuryConfig(treasuryId: String) async throws -> TreasuryConfig {
        try await request(.treasuryConfig(treasuryId: treasuryId))
    }

    // MARK: - Activity Endpoints

    func getRecentActivity(accountId: String, limit: Int = 10, offset: Int = 0) async throws -> RecentActivityResponse {
        try await request(.recentActivity(accountId: accountId, limit: limit, offset: offset))
    }

    // MARK: - Profile Endpoints

    func getUserProfile(accountId: String) async throws -> UserProfile {
        try await request(.userProfile(accountId: accountId))
    }
}
