import SwiftUI

struct MembersListView: View {
    @Environment(TreasuryAPIClient.self) private var apiClient
    @State private var viewModel = MembersListViewModel()
    @State private var searchText = ""

    let treasury: Treasury

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .loading:
                    LoadingView(message: "Loading members...")

                case .loaded:
                    if viewModel.members.isEmpty {
                        EmptyStateView(
                            title: "No Members",
                            description: "This treasury has no members",
                            systemImage: "person.3"
                        )
                    } else {
                        membersList
                    }

                case .error(let error):
                    ErrorView(error: error) {
                        Task {
                            await loadMembers()
                        }
                    }
                }
            }
            .navigationTitle("Members")
            .searchable(text: $searchText, prompt: "Search members")
            .refreshable {
                await loadMembers()
            }
        }
        .task {
            await loadMembers()
        }
    }

    private var membersList: some View {
        List {
            ForEach(groupedMembers.keys.sorted(), id: \.self) { role in
                Section(role) {
                    ForEach(groupedMembers[role] ?? []) { member in
                        MemberRowView(member: member)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var groupedMembers: [String: [Member]] {
        var result: [String: [Member]] = [:]

        for member in filteredMembers {
            for role in member.roles {
                if result[role] == nil {
                    result[role] = []
                }
                result[role]?.append(member)
            }
        }

        return result
    }

    private var filteredMembers: [Member] {
        if searchText.isEmpty {
            return viewModel.members
        }
        return viewModel.members.filter { member in
            member.accountId.localizedCaseInsensitiveContains(searchText) ||
            member.roles.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private func loadMembers() async {
        await viewModel.loadMembers(treasuryId: treasury.daoId, apiClient: apiClient)
    }
}

#Preview {
    MembersListView(treasury: Treasury(daoId: "test.sputnik-dao.near", config: nil))
        .environment(TreasuryAPIClient.shared)
}
