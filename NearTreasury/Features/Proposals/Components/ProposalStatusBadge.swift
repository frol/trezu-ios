import SwiftUI

struct ProposalStatusBadge: View {
    let status: ProposalStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(backgroundColor)
            .clipShape(Capsule())
    }

    private var foregroundColor: Color {
        switch status {
        case .approved:
            return .green
        case .rejected:
            return .red
        case .inProgress:
            return .orange
        case .expired:
            return .gray
        case .removed:
            return .gray
        case .failed:
            return .red
        }
    }

    private var backgroundColor: Color {
        foregroundColor.opacity(0.15)
    }
}

#Preview {
    VStack(spacing: 12) {
        ProposalStatusBadge(status: .approved)
        ProposalStatusBadge(status: .rejected)
        ProposalStatusBadge(status: .inProgress)
        ProposalStatusBadge(status: .expired)
        ProposalStatusBadge(status: .failed)
    }
    .padding()
}
