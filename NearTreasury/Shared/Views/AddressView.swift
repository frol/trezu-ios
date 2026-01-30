import SwiftUI

struct AddressView: View {
    let address: String
    var truncate: Bool = true
    var showCopyButton: Bool = true

    @State private var copied = false

    var body: some View {
        HStack(spacing: 4) {
            Text(displayAddress)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.primary)

            if showCopyButton {
                Button {
                    copyToClipboard()
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(copied ? .green : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var displayAddress: String {
        guard truncate, address.count > 20 else { return address }

        let start = address.prefix(8)
        let end = address.suffix(6)
        return "\(start)...\(end)"
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = address
        copied = true

        Task {
            try? await Task.sleep(for: .seconds(2))
            copied = false
        }
    }
}

struct AccountAvatar: View {
    let accountId: String
    var size: CGFloat = 40
    var imageURL: URL?

    var body: some View {
        Group {
            if let imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure, .empty:
                        fallbackAvatar
                    @unknown default:
                        fallbackAvatar
                    }
                }
            } else {
                fallbackAvatar
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var fallbackAvatar: some View {
        ZStack {
            Circle()
                .fill(avatarColor.gradient)

            Text(accountId.prefix(1).uppercased())
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private var avatarColor: Color {
        let colors: [Color] = [.blue, .purple, .orange, .green, .pink, .teal, .indigo, .cyan]
        let index = abs(accountId.hashValue) % colors.count
        return colors[index]
    }
}

#Preview {
    VStack(spacing: 20) {
        AddressView(address: "alice.near")
        AddressView(address: "0x1234567890abcdef1234567890abcdef12345678")
        AddressView(address: "very-long-account-name.near", truncate: false)

        HStack {
            AccountAvatar(accountId: "alice.near")
            AccountAvatar(accountId: "bob.near", size: 32)
            AccountAvatar(accountId: "charlie.near", size: 24)
        }
    }
    .padding()
}
