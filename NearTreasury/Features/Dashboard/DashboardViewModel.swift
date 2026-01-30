import Foundation

@Observable
final class DashboardViewModel {
    enum State {
        case loading
        case loaded
        case error(Error)
    }

    private(set) var state: State = .loading
    private(set) var assets: [TreasuryAsset] = []
    private(set) var totalBalanceUSD: Double = 0
    private(set) var pendingProposals: [Proposal] = []
    private(set) var recentActivities: [RecentActivity] = []

    var formattedTotalBalance: String {
        if totalBalanceUSD >= 1_000_000 {
            return String(format: "$%.2fM", totalBalanceUSD / 1_000_000)
        } else if totalBalanceUSD >= 1_000 {
            return String(format: "$%.2fK", totalBalanceUSD / 1_000)
        } else {
            return String(format: "$%.2f", totalBalanceUSD)
        }
    }

    func loadDashboard(treasuryId: String, apiClient: TreasuryAPIClient) async {
        state = .loading

        do {
            // Load assets using user/assets endpoint (treasury account ID)
            print("Loading assets for: \(treasuryId)")
            let assetsResponse = try await apiClient.getUserAssets(accountId: treasuryId)
            assets = assetsResponse.assets
            totalBalanceUSD = assetsResponse.totalBalanceUSD
            print("Loaded \(assets.count) assets")

            // Load pending proposals
            print("Loading proposals for: \(treasuryId)")
            let proposalFilters = ProposalFilters(status: .inProgress, limit: 4, offset: 0)
            let proposalsResponse = try await apiClient.getProposals(daoId: treasuryId, filters: proposalFilters)
            pendingProposals = proposalsResponse.proposals
            print("Loaded \(pendingProposals.count) pending proposals")

            // Load recent activity
            print("Loading activity for: \(treasuryId)")
            let activityResponse = try await apiClient.getRecentActivity(accountId: treasuryId, limit: 5, offset: 0)
            recentActivities = activityResponse.activities
            print("Loaded \(recentActivities.count) activities")

            state = .loaded
        } catch {
            print("Dashboard load error: \(error)")
            state = .error(error)
        }
    }
}
