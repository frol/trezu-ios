import SwiftUI

struct ErrorView: View {
    let error: Error
    var retryAction: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label("Error", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error.localizedDescription)
        } actions: {
            if let retryAction {
                Button("Try Again", action: retryAction)
                    .buttonStyle(.bordered)
            }
        }
    }
}

struct EmptyStateView: View {
    let title: String
    let description: String
    let systemImage: String
    var action: (() -> Void)?
    var actionTitle: String?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(description)
        } actions: {
            if let action, let actionTitle {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
            }
        }
    }
}

#Preview("Error View") {
    ErrorView(
        error: NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Something went wrong"]),
        retryAction: {}
    )
}

#Preview("Empty State") {
    EmptyStateView(
        title: "No Proposals",
        description: "There are no proposals to display",
        systemImage: "doc.text",
        action: {},
        actionTitle: "Create Proposal"
    )
}
