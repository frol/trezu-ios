import Foundation

@Observable
final class TreasuryListViewModel {
    enum State {
        case loading
        case loaded([Treasury])
        case error(Error)
    }

    private(set) var state: State = .loading

    func loadTreasuries(accountId: String, apiClient: TreasuryAPIClient) async {
        state = .loading

        do {
            let treasuries = try await apiClient.getUserTreasuries(accountId: accountId)
            state = .loaded(treasuries)
        } catch {
            state = .error(error)
        }
    }
}
