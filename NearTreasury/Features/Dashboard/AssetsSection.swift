import SwiftUI

struct AssetsSection: View {
    let assets: [TreasuryAsset]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Assets")
                    .font(.headline)

                Spacer()

                if assets.count > 5 {
                    Text("View All")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            }

            if assets.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(assets.prefix(5))) { asset in
                        AssetRowView(asset: asset)

                        if asset.id != assets.prefix(5).last?.id {
                            Divider()
                                .padding(.leading, 52)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.05), radius: 4, y: 1)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "banknote")
                .font(.title)
                .foregroundStyle(.secondary)

            Text("No assets")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct AssetRowView: View {
    let asset: TreasuryAsset

    var body: some View {
        HStack(spacing: 12) {
            TokenIcon(symbol: asset.symbol, iconURL: asset.icon)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(asset.symbol)
                        .font(.headline)

                    if asset.residency != .near {
                        ChainBadge(residency: asset.residency)
                    }
                }

                Text(asset.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(asset.formattedBalance)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(asset.formattedBalanceUSD)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }
}

#Preview {
    AssetsSection(assets: [
        TreasuryAsset(
            id: "1",
            contractId: nil,
            residency: .near,
            symbol: "NEAR",
            balance: "1000000000000000000000000",
            decimals: 24,
            price: 5.50,
            name: "NEAR Protocol",
            icon: nil,
            balanceUSD: 5500
        ),
        TreasuryAsset(
            id: "2",
            contractId: "usdc.near",
            residency: .near,
            symbol: "USDC",
            balance: "1000000000",
            decimals: 6,
            price: 1.0,
            name: "USD Coin",
            icon: nil,
            balanceUSD: 1000
        )
    ])
    .padding()
    .background(Color(.systemGroupedBackground))
}
