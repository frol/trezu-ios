import SwiftUI
import NEARConnect

struct TreasuryListView: View {
    @Environment(AuthService.self) private var authService
    @Environment(TreasuryService.self) private var treasuryService
    @EnvironmentObject private var walletManager: NEARWalletManager
    @State private var searchText = ""
    @State private var showAddTreasury = false

    var filteredTreasuries: [Treasury] {
        let visible = treasuryService.treasuries.filter { !$0.isHidden }
        if searchText.isEmpty { return visible }
        return visible.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.daoId.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if treasuryService.isLoading && treasuryService.treasuries.isEmpty {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView("Loading treasuries...")
                            Spacer()
                        }
                        .padding(.vertical, 32)
                    }
                } else if filteredTreasuries.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No Treasuries",
                            systemImage: "building.columns",
                            description: Text("You don't have access to any treasuries yet.")
                        )
                    }
                } else {
                    Section {
                        ForEach(filteredTreasuries) { treasury in
                            TreasuryRow(treasury: treasury)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    Task {
                                        await treasuryService.selectTreasury(treasury)
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle("Treasuries")
            .searchable(text: $searchText, prompt: "Search treasuries")
            .refreshable {
                await treasuryService.loadTreasuries()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if let account = walletManager.currentAccount {
                            Section {
                                Label(account.displayName, systemImage: "person.circle")
                            }
                        }
                        Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right") {
                            Task { await authService.signOut(walletManager: walletManager) }
                        }
                    } label: {
                        Image(systemName: "person.circle")
                    }
                }
            }
        }
    }
}

// MARK: - Treasury Row

struct TreasuryRow: View {
    let treasury: Treasury

    var body: some View {
        HStack(spacing: 12) {
            // Treasury icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(String(treasury.name.prefix(1)).uppercased())
                    .font(.headline.bold())
                    .foregroundStyle(.tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(treasury.name)
                    .font(.body.weight(.medium))

                Text(treasury.daoId)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 4) {
                if treasury.isMember {
                    Image(systemName: "person.fill.checkmark")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
