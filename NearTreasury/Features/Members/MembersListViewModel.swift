import Foundation

@Observable
final class MembersListViewModel {
    enum State {
        case loading
        case loaded
        case error(Error)
    }

    private(set) var state: State = .loading
    private(set) var members: [Member] = []
    private(set) var policy: Policy?

    func loadMembers(treasuryId: String, apiClient: TreasuryAPIClient) async {
        state = .loading

        do {
            print("Loading policy for: \(treasuryId)")
            let policy = try await apiClient.getTreasuryPolicy(treasuryId: treasuryId)
            self.policy = policy
            self.members = policy.allMembers
            print("Loaded \(members.count) members")
            state = .loaded
        } catch {
            print("Members load error: \(error)")
            state = .error(error)
        }
    }
}
