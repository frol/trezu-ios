import SwiftUI

struct DashboardView: View {
    @Environment(TreasuryService.self) private var treasuryService
    @State private var showTreasuryPicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                ZStack(alignment: .top) {
                    // Blue header background
                    blueHeader

                    // Content overlay
                    VStack(spacing: 0) {
                        // Spacing for status bar + header content
                        Spacer()
                            .frame(height: headerContentHeight)

                        // Portfolio card overlapping the blue area
                        portfolioCard
                            .padding(.horizontal, 16)
                            .offset(y: -40)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .ignoresSafeArea(edges: .top)
            .navigationBarHidden(true)
            .refreshable {
                await treasuryService.refresh()
            }
            .sheet(isPresented: $showTreasuryPicker) {
                TreasuryPickerSheet()
            }
        }
    }

    // MARK: - Blue Header

    private let headerContentHeight: CGFloat = 280

    @ViewBuilder
    private var blueHeader: some View {
        ZStack {
            // Blue gradient
            LinearGradient(
                colors: [Color(red: 0.2, green: 0.45, blue: 1.0), Color(red: 0.25, green: 0.5, blue: 1.0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: headerContentHeight + 40)

            VStack(spacing: 16) {
                Spacer()
                    .frame(height: 54) // Status bar offset

                // Treasury selector pill
                treasurySelectorPill

                // Total balance
                VStack(spacing: 6) {
                    Text("Total Balance")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))

                    if treasuryService.isLoading && treasuryService.totalBalanceUSD == 0 {
                        ProgressView()
                            .tint(.white)
                            .frame(height: 40)
                    } else {
                        Text(formatCurrency(treasuryService.totalBalanceUSD))
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }

                Spacer()
            }
            .frame(height: headerContentHeight + 40)
        }
    }

    // MARK: - Treasury Selector Pill

    @ViewBuilder
    private var treasurySelectorPill: some View {
        let name = treasuryService.selectedTreasury?.name ?? "Treasury"

        Button {
            showTreasuryPicker = true
        } label: {
            HStack(spacing: 8) {
                // Treasury icon
                Circle()
                    .fill(.white.opacity(0.25))
                    .frame(width: 28, height: 28)
                    .overlay {
                        Text(String(name.prefix(1)).uppercased())
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }

                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.white.opacity(0.15), in: Capsule())
        }
    }

    // MARK: - Portfolio Card

    @ViewBuilder
    private var portfolioCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !treasuryService.assets.isEmpty {
                Text("Portfolio")
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                ForEach(Array(treasuryService.assets.enumerated()), id: \.element.id) { index, asset in
                    HStack(spacing: 12) {
                        TokenIconView(icon: asset.icon, symbol: asset.symbol)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(asset.symbol)
                                .font(.body.weight(.medium))
                            Text(asset.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(asset.formattedBalance)
                                .font(.body.weight(.medium))
                            Text(asset.formattedBalanceUSD)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    if index < treasuryService.assets.count - 1 {
                        Divider()
                            .padding(.leading, 64)
                    }
                }

                Spacer()
                    .frame(height: 12)
            } else if treasuryService.isLoading {
                VStack {
                    ProgressView()
                        .padding(.vertical, 40)
                }
                .frame(maxWidth: .infinity)
            } else {
                ContentUnavailableView(
                    "No Assets",
                    systemImage: "wallet.bifold",
                    description: Text("This treasury has no assets yet.")
                )
                .padding(.vertical, 20)
            }
        }
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }
}

// MARK: - Token Icon View

struct TokenIconView: View {
    let icon: String?
    let symbol: String

    var body: some View {
        Group {
            if let icon = icon, let url = URL(string: icon) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    default:
                        tokenPlaceholder
                    }
                }
            } else {
                tokenPlaceholder
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(Circle())
    }

    private var tokenPlaceholder: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.15))
            Text(String(symbol.prefix(1)))
                .font(.subheadline.bold())
                .foregroundStyle(.tint)
        }
    }
}
// MARK: - Treasury Picker Sheet

struct TreasuryPickerSheet: View {
    @Environment(TreasuryService.self) private var treasuryService
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredTreasuries: [Treasury] {
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
                ForEach(filteredTreasuries) { treasury in
                    Button {
                        Task {
                            await treasuryService.selectTreasury(treasury)
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 12) {
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

                            if treasury.id == treasuryService.selectedTreasury?.id {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.tint)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .tint(.primary)
                }
            }
            .navigationTitle("Switch Treasury")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search treasuries")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

