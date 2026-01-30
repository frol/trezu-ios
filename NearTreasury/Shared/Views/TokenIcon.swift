import SwiftUI

struct TokenIcon: View {
    let symbol: String
    let iconURL: String?
    var size: CGFloat = 40

    var body: some View {
        Group {
            if let iconURL, let url = URL(string: iconURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure, .empty:
                        fallbackIcon
                    @unknown default:
                        fallbackIcon
                    }
                }
            } else {
                fallbackIcon
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var fallbackIcon: some View {
        ZStack {
            Circle()
                .fill(symbolColor.gradient)

            Text(symbol.prefix(1).uppercased())
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private var symbolColor: Color {
        let colors: [Color] = [.blue, .purple, .orange, .green, .pink, .teal, .indigo]
        let index = abs(symbol.hashValue) % colors.count
        return colors[index]
    }
}

struct ChainBadge: View {
    let residency: TokenResidency

    var body: some View {
        Text(residency.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(residency.color.opacity(0.2))
            .foregroundStyle(residency.color)
            .clipShape(Capsule())
    }
}

extension TokenResidency {
    var displayName: String {
        switch self {
        case .near: return "NEAR"
        case .ft: return "FT"
        case .intents: return "Intents"
        case .aurora: return "Aurora"
        case .base: return "Base"
        case .ethereum: return "ETH"
        case .arbitrum: return "Arbitrum"
        case .solana: return "Solana"
        case .bitcoin: return "BTC"
        case .unknown: return "Unknown"
        }
    }

    var color: Color {
        switch self {
        case .near: return .blue
        case .ft: return .teal
        case .intents: return .purple
        case .aurora: return .green
        case .base: return .blue
        case .ethereum: return .purple
        case .arbitrum: return .blue
        case .solana: return .purple
        case .bitcoin: return .orange
        case .unknown: return .gray
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        TokenIcon(symbol: "NEAR", iconURL: nil)
        TokenIcon(symbol: "USDC", iconURL: nil, size: 32)
        TokenIcon(symbol: "ETH", iconURL: "https://cryptologos.cc/logos/ethereum-eth-logo.png")

        HStack {
            ChainBadge(residency: .near)
            ChainBadge(residency: .ethereum)
            ChainBadge(residency: .base)
        }
    }
    .padding()
}
