import Foundation

@Observable
final class ProposalsListViewModel {
    enum State {
        case loading
        case loaded
        case error(Error)
    }

    enum Filter: CaseIterable {
        case all
        case pending
        case approved
        case rejected
        case expired

        var title: String {
            switch self {
            case .all: return "All"
            case .pending: return "Pending"
            case .approved: return "Approved"
            case .rejected: return "Rejected"
            case .expired: return "Expired"
            }
        }

        var status: ProposalStatus? {
            switch self {
            case .all: return nil
            case .pending: return .inProgress
            case .approved: return .approved
            case .rejected: return .rejected
            case .expired: return .expired
            }
        }
    }

    private(set) var state: State = .loading
    private(set) var proposals: [Proposal] = []

    var selectedFilter: Filter = .all

    var filteredProposals: [Proposal] {
        guard let status = selectedFilter.status else {
            return proposals
        }
        return proposals.filter { $0.status == status }
    }

    func countForFilter(_ filter: Filter) -> Int {
        guard let status = filter.status else {
            return proposals.count
        }
        return proposals.filter { $0.status == status }.count
    }

    func loadProposals(daoId: String, apiClient: TreasuryAPIClient) async {
        state = .loading

        do {
            print("Loading proposals for: \(daoId)")
            let filters = ProposalFilters(limit: 100, offset: 0)
            let response = try await apiClient.getProposals(daoId: daoId, filters: filters)
            proposals = response.proposals.sorted { $0.id > $1.id }
            print("Loaded \(proposals.count) proposals")
            state = .loaded
        } catch {
            print("Proposals load error: \(error)")
            state = .error(error)
        }
    }
}
