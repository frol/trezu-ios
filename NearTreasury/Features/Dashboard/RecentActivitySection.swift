import SwiftUI

struct RecentActivitySection: View {
    let activities: [RecentActivity]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)

                Spacer()

                if activities.count > 5 {
                    Text("View All")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            }

            if activities.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(activities.prefix(5))) { activity in
                        ActivityRowView(activity: activity)

                        if activity.id != activities.prefix(5).last?.id {
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
            Image(systemName: "clock")
                .font(.title)
                .foregroundStyle(.secondary)

            Text("No recent activity")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ActivityRowView: View {
    let activity: RecentActivity

    var body: some View {
        HStack(spacing: 12) {
            // Activity icon
            ZStack {
                Circle()
                    .fill(activityColor.opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(systemName: activityIcon)
                    .foregroundStyle(activityColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(activity.actionDescription)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }

                if let amount = activity.amount, let symbol = activity.tokenMetadata?.symbol {
                    Text("\(amount) \(symbol)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if let counterparty = activity.counterparty {
                    Text(counterparty)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(activity.formattedTime)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    private var activityIcon: String {
        if activity.counterparty == "STAKING_REWARD" {
            return "star.fill"
        }
        return "arrow.right.arrow.left"
    }

    private var activityColor: Color {
        if activity.counterparty == "STAKING_REWARD" {
            return .yellow
        }
        return .blue
    }
}

#Preview {
    RecentActivitySection(activities: [])
        .padding()
        .background(Color(.systemGroupedBackground))
}
