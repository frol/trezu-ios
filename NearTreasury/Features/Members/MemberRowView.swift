import SwiftUI

struct MemberRowView: View {
    let member: Member

    var body: some View {
        HStack(spacing: 12) {
            AccountAvatar(accountId: member.accountId, size: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(member.accountId)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    ForEach(member.roles, id: \.self) { role in
                        RoleBadge(role: role)
                    }
                }
            }

            Spacer()

            Button {
                copyToClipboard(member.accountId)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
    }
}

struct RoleBadge: View {
    let role: String

    var body: some View {
        Text(role)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(roleColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(roleColor.opacity(0.15))
            .clipShape(Capsule())
    }

    private var roleColor: Color {
        switch role.lowercased() {
        case "council", "admin":
            return .purple
        case "member":
            return .blue
        case "treasurer", "finance":
            return .green
        case "developer", "dev":
            return .orange
        default:
            return .gray
        }
    }
}

#Preview {
    List {
        MemberRowView(member: Member(
            accountId: "alice.near",
            roles: ["council", "treasurer"]
        ))
        MemberRowView(member: Member(
            accountId: "very-long-account-name-that-might-truncate.near",
            roles: ["member"]
        ))
    }
    .listStyle(.insetGrouped)
}
