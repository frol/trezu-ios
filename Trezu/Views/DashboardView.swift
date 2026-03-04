import SwiftUI
import Charts

struct DashboardView: View {
    @Environment(TreasuryService.self) private var treasuryService

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Total Balance Card
                    BalanceCard(
                        totalUSD: treasuryService.totalBalanceUSD,
                        isLoading: treasuryService.isLoading
                    )

                    // Balance History Chart
                    if !treasuryService.balanceHistory.isEmpty {
                        BalanceChartCard(history: treasuryService.balanceHistory)
                    }

                    // Portfolio Assets
                    if !treasuryService.assets.isEmpty {
                        AssetsCard(assets: treasuryService.assets)
                    }

                    // Recent Activity
//                    if !treasuryService.recentActivity.isEmpty {
//                        RecentActivityCard(activity: treasuryService.recentActivity)
//                    }
                }
                .padding()
            }
            .navigationTitle(treasuryService.selectedTreasury?.name ?? "Dashboard")
            .refreshable {
                await treasuryService.refresh()
            }
        }
    }
}

// MARK: - Balance Card

struct BalanceCard: View {
    let totalUSD: Double
    let isLoading: Bool

    var body: some View {
        VStack(spacing: 8) {
            Text("Total Balance")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if isLoading && totalUSD == 0 {
                ProgressView()
                    .frame(height: 36)
            } else {
                Text(formatCurrency(totalUSD))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Balance Chart Card

struct BalanceChartCard: View {
    let history: [BalanceHistoryPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Balance History")
                .font(.headline)

            Chart {
                ForEach(history) { point in
                    if let date = point.date {
                        LineMark(
                            x: .value("Date", date),
                            y: .value("Balance", point.totalBalanceUsd)
                        )
                        .foregroundStyle(.tint)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Date", date),
                            y: .value("Balance", point.totalBalanceUsd)
                        )
                        .foregroundStyle(
                            .linearGradient(
                                colors: [.accentColor.opacity(0.2), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let usd = value.as(Double.self) {
                            Text(formatCurrency(usd))
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 200)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Assets Card

struct AssetsCard: View {
    let assets: [TreasuryAsset]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Portfolio")
                .font(.headline)

            ForEach(assets) { asset in
                HStack {
                    // Token icon placeholder
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
                .padding(.vertical, 4)

                if asset.id != assets.last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Recent Activity Card

struct RecentActivityCard: View {
    let activity: [ActivityItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)

            ForEach(activity) { item in
                HStack {
                    Image(systemName: item.isIncoming ? "arrow.down.left.circle.fill" : "arrow.up.right.circle.fill")
                        .foregroundStyle(item.isIncoming ? .green : .orange)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.counterparty ?? "Unknown")
                            .font(.body.weight(.medium))
                            .lineLimit(1)
                        if let date = item.activityDate {
                            Text(date, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Text(item.formattedAmount)
                        .font(.body.weight(.medium))
                        .foregroundStyle(item.isIncoming ? .green : .primary)
                }
                .padding(.vertical, 4)

                if item.id != activity.last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
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
