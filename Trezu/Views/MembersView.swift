import SwiftUI
import NEARConnect

struct MembersView: View {
    @Environment(TreasuryService.self) private var treasuryService
    @EnvironmentObject private var walletManager: NEARWalletManager
    @State private var searchText = ""
    @State private var showAddMember = false

    var filteredMembers: [Member] {
        if searchText.isEmpty { return treasuryService.members }
        return treasuryService.members.filter {
            $0.accountId.localizedCaseInsensitiveContains(searchText)
        }
    }

    var membersByRole: [(String, [Member])] {
        let roles = ["Governance", "Financial", "Requestor"]
        return roles.compactMap { role in
            let members = filteredMembers.filter { $0.roles.contains(role) }
            if members.isEmpty { return nil }
            return (role, members)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if treasuryService.members.isEmpty && treasuryService.isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.vertical, 32)
                    }
                } else if filteredMembers.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No Members",
                            systemImage: "person.3",
                            description: Text("No members found.")
                        )
                    }
                } else {
                    ForEach(membersByRole, id: \.0) { role, members in
                        Section {
                            ForEach(members) { member in
                                MemberRow(member: member)
                            }
                        } header: {
                            HStack {
                                RoleBadge(role: role)
                                Spacer()
                                Text("\(members.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Approval thresholds
                if let policy = treasuryService.policy {
                    Section("Approval Thresholds") {
                        ForEach(policy.roles) { role in
                            if let votePolicy = role.votePolicy?.values.first ?? Optional(policy.defaultVotePolicy) {
                                HStack {
                                    Text(role.name)
                                        .font(.body.weight(.medium))
                                    Spacer()
                                    if let threshold = votePolicy.threshold {
                                        Text(threshold.displayString)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Members")
            .searchable(text: $searchText, prompt: "Search members")
            .refreshable {
                await treasuryService.refresh()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddMember = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showAddMember) {
                AddMemberView()
            }
        }
    }
}

// MARK: - Member Row

struct MemberRow: View {
    let member: Member

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                Text(String(member.accountId.prefix(1)).uppercased())
                    .font(.subheadline.bold())
                    .foregroundStyle(.tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(member.accountId)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    ForEach(member.roles, id: \.self) { role in
                        RoleBadge(role: role)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Role Badge

struct RoleBadge: View {
    let role: String

    var color: Color {
        switch role {
        case "Governance": return .purple
        case "Financial": return .blue
        case "Requestor": return .orange
        default: return .gray
        }
    }

    var body: some View {
        Text(role)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

// MARK: - Add Member View

struct AddMemberView: View {
    @Environment(TreasuryService.self) private var treasuryService
    @EnvironmentObject private var walletManager: NEARWalletManager
    @Environment(\.dismiss) private var dismiss

    @State private var accountId = ""
    @State private var selectedRole = "Requestor"
    @State private var description = ""
    @State private var isSubmitting = false
    @State private var error: String?

    let roles = ["Governance", "Financial", "Requestor"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Member Details") {
                    TextField("Account ID (e.g. alice.near)", text: $accountId)
                        .textContentType(.username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Picker("Role", selection: $selectedRole) {
                        ForEach(roles, id: \.self) { role in
                            Text(role).tag(role)
                        }
                    }
                }

                Section("Description") {
                    TextField("Reason for adding this member", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        Task { await submitProposal() }
                    }
                    .disabled(accountId.isEmpty || isSubmitting)
                }
            }
        }
    }

    private func submitProposal() async {
        isSubmitting = true
        error = nil
        do {
            let desc = description.isEmpty ? "Add \(accountId) as \(selectedRole)" : description
            _ = try await treasuryService.createAddMemberProposal(
                description: desc,
                memberId: accountId,
                role: selectedRole,
                walletManager: walletManager
            )
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isSubmitting = false
    }
}
