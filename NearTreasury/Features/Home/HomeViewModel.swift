import Foundation

@Observable
final class HomeViewModel {
    private static let recentTreasuriesKey = "NearTreasury.RecentTreasuries"
    private static let maxRecentTreasuries = 10

    var searchQuery: String = ""
    var searchResult: Treasury?
    var searchError: String?
    var isSearching: Bool = false

    var recentTreasuries: [TreasurySummary] = []
    var myTreasuries: [Treasury] = []
    var isLoadingMyTreasuries: Bool = false

    init() {
        loadRecentTreasuries()
    }

    // MARK: - Treasury Search

    func searchTreasury(apiClient: TreasuryAPIClient) async {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        isSearching = true
        searchError = nil
        searchResult = nil

        do {
            // Validate treasury exists by fetching its config
            let config = try await apiClient.getTreasuryConfig(treasuryId: query)
            let treasury = Treasury(daoId: query, config: config)
            searchResult = treasury
            addToRecentTreasuries(treasury)
        } catch let error as APIError {
            switch error {
            case .httpError(let code, _) where code == 404:
                searchError = "Treasury not found: \(query)"
            default:
                searchError = "Failed to load treasury: \(error.localizedDescription)"
            }
        } catch {
            searchError = "Failed to load treasury: \(error.localizedDescription)"
        }

        isSearching = false
    }

    func clearSearch() {
        searchQuery = ""
        searchResult = nil
        searchError = nil
    }

    // MARK: - My Treasuries

    func loadMyTreasuries(accountId: String, apiClient: TreasuryAPIClient) async {
        isLoadingMyTreasuries = true

        do {
            myTreasuries = try await apiClient.getUserTreasuries(accountId: accountId)
        } catch {
            print("Failed to load treasuries: \(error)")
            myTreasuries = []
        }

        isLoadingMyTreasuries = false
    }

    func clearMyTreasuries() {
        myTreasuries = []
    }

    // MARK: - Recent Treasuries Persistence

    private func loadRecentTreasuries() {
        guard let data = UserDefaults.standard.data(forKey: Self.recentTreasuriesKey),
              let treasuries = try? JSONDecoder().decode([TreasurySummary].self, from: data) else {
            recentTreasuries = []
            return
        }
        recentTreasuries = treasuries
    }

    private func saveRecentTreasuries() {
        guard let data = try? JSONEncoder().encode(recentTreasuries) else { return }
        UserDefaults.standard.set(data, forKey: Self.recentTreasuriesKey)
    }

    func addToRecentTreasuries(_ treasury: Treasury) {
        let summary = TreasurySummary(
            daoId: treasury.daoId,
            name: treasury.displayName,
            lastAccessed: Date()
        )

        // Remove existing entry if present
        recentTreasuries.removeAll { $0.daoId == treasury.daoId }

        // Add to front of list
        recentTreasuries.insert(summary, at: 0)

        // Limit to max entries
        if recentTreasuries.count > Self.maxRecentTreasuries {
            recentTreasuries = Array(recentTreasuries.prefix(Self.maxRecentTreasuries))
        }

        saveRecentTreasuries()
    }

    func removeFromRecentTreasuries(_ treasuryId: String) {
        recentTreasuries.removeAll { $0.daoId == treasuryId }
        saveRecentTreasuries()
    }

    func clearRecentTreasuries() {
        recentTreasuries = []
        saveRecentTreasuries()
    }
}

// MARK: - TreasurySummary Extension

extension TreasurySummary {
    var formattedLastAccessed: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastAccessed, relativeTo: Date())
    }
}
