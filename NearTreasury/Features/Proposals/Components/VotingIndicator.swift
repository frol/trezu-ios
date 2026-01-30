import SwiftUI

struct VotingIndicator: View {
    let approveCount: Int
    let rejectCount: Int

    var body: some View {
        HStack(spacing: 8) {
            // Approve count
            HStack(spacing: 3) {
                Image(systemName: "checkmark")
                    .font(.caption2)
                Text("\(approveCount)")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.green)

            // Divider
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1, height: 12)

            // Reject count
            HStack(spacing: 3) {
                Image(systemName: "xmark")
                    .font(.caption2)
                Text("\(rejectCount)")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.red)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
        .clipShape(Capsule())
    }
}

struct VotingProgress: View {
    let approveCount: Int
    let rejectCount: Int
    let threshold: Int

    var total: Int {
        approveCount + rejectCount
    }

    var approveProgress: CGFloat {
        guard threshold > 0 else { return 0 }
        return min(CGFloat(approveCount) / CGFloat(threshold), 1.0)
    }

    var rejectProgress: CGFloat {
        guard threshold > 0 else { return 0 }
        return min(CGFloat(rejectCount) / CGFloat(threshold), 1.0)
    }

    var body: some View {
        VStack(spacing: 8) {
            // Approve progress
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.caption)
                    .foregroundStyle(.green)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.green.opacity(0.2))
                            .frame(height: 8)
                            .clipShape(Capsule())

                        Rectangle()
                            .fill(Color.green)
                            .frame(width: geometry.size.width * approveProgress, height: 8)
                            .clipShape(Capsule())
                    }
                }
                .frame(height: 8)

                Text("\(approveCount)/\(threshold)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)
            }

            // Reject progress
            HStack(spacing: 8) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.red)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.red.opacity(0.2))
                            .frame(height: 8)
                            .clipShape(Capsule())

                        Rectangle()
                            .fill(Color.red)
                            .frame(width: geometry.size.width * rejectProgress, height: 8)
                            .clipShape(Capsule())
                    }
                }
                .frame(height: 8)

                Text("\(rejectCount)/\(threshold)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)
            }
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        VotingIndicator(approveCount: 3, rejectCount: 1)

        VotingProgress(approveCount: 2, rejectCount: 1, threshold: 3)
            .padding()
    }
    .padding()
}
