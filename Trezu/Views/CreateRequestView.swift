import SwiftUI
import NEARConnect

struct CreateRequestView: View {
    @Environment(TreasuryService.self) private var treasuryService
    @EnvironmentObject private var walletManager: NEARWalletManager
    @Environment(\.dismiss) private var dismiss

    @State private var requestType: RequestType = .transfer
    @State private var description = ""
    @State private var recipient = ""
    @State private var amount = ""
    @State private var selectedTokenIndex = 0
    @State private var isSubmitting = false
    @State private var error: String?

    enum RequestType: String, CaseIterable {
        case transfer = "Transfer"
        case addMember = "Add Member"
        case removeMember = "Remove Member"
    }

    // For member proposals
    @State private var memberId = ""
    @State private var memberRole = "Requestor"

    var body: some View {
        NavigationStack {
            Form {
                Section("Request Type") {
                    Picker("Type", selection: $requestType) {
                        ForEach(RequestType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                switch requestType {
                case .transfer:
                    transferForm
                case .addMember:
                    addMemberForm
                case .removeMember:
                    removeMemberForm
                }

                Section("Description") {
                    TextField("Describe this request", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        Task { await submit() }
                    }
                    .disabled(!isFormValid || isSubmitting)
                }
            }
        }
    }

    // MARK: - Transfer Form

    @ViewBuilder
    private var transferForm: some View {
        Section("Transfer Details") {
            TextField("Recipient (e.g. alice.near)", text: $recipient)
                .textContentType(.username)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            TextField("Amount", text: $amount)
                .keyboardType(.decimalPad)

            if !treasuryService.assets.isEmpty {
                Picker("Token", selection: $selectedTokenIndex) {
                    ForEach(Array(treasuryService.assets.enumerated()), id: \.offset) { index, asset in
                        HStack {
                            Text(asset.symbol)
                            Text("(\(asset.formattedBalance))")
                                .foregroundStyle(.secondary)
                        }
                        .tag(index)
                    }
                }
            } else {
                Text("NEAR")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Add Member Form

    @ViewBuilder
    private var addMemberForm: some View {
        Section("Member Details") {
            TextField("Account ID (e.g. alice.near)", text: $memberId)
                .textContentType(.username)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            Picker("Role", selection: $memberRole) {
                Text("Governance").tag("Governance")
                Text("Financial").tag("Financial")
                Text("Requestor").tag("Requestor")
            }
        }
    }

    // MARK: - Remove Member Form

    @ViewBuilder
    private var removeMemberForm: some View {
        Section("Member to Remove") {
            if treasuryService.members.isEmpty {
                Text("No members loaded")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Member", selection: $memberId) {
                    Text("Select member").tag("")
                    ForEach(treasuryService.members) { member in
                        Text(member.accountId).tag(member.accountId)
                    }
                }

                if !memberId.isEmpty {
                    let member = treasuryService.members.first { $0.accountId == memberId }
                    if let member {
                        Picker("Role", selection: $memberRole) {
                            ForEach(member.roles, id: \.self) { role in
                                Text(role).tag(role)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        switch requestType {
        case .transfer:
            return !recipient.isEmpty && !amount.isEmpty
        case .addMember:
            return !memberId.isEmpty
        case .removeMember:
            return !memberId.isEmpty
        }
    }

    // MARK: - Submit

    private func submit() async {
        isSubmitting = true
        error = nil

        do {
            switch requestType {
            case .transfer:
                let asset = treasuryService.assets.indices.contains(selectedTokenIndex)
                    ? treasuryService.assets[selectedTokenIndex] : nil
                let tokenId = asset?.tokenId
                let decimals = asset?.decimals ?? 24

                // Convert human-readable amount to raw amount
                let rawAmount: String
                if let amtDouble = Double(amount) {
                    let multiplier = pow(10.0, Double(decimals))
                    let raw = amtDouble * multiplier
                    rawAmount = String(format: "%.0f", raw)
                } else {
                    rawAmount = amount
                }

                let desc = description.isEmpty
                    ? "Transfer \(amount) \(asset?.symbol ?? "NEAR") to \(recipient)"
                    : description

                _ = try await treasuryService.createTransferProposal(
                    description: desc,
                    receiverId: recipient,
                    amount: rawAmount,
                    tokenId: tokenId,
                    walletManager: walletManager
                )

            case .addMember:
                let desc = description.isEmpty
                    ? "Add \(memberId) as \(memberRole)"
                    : description
                _ = try await treasuryService.createAddMemberProposal(
                    description: desc,
                    memberId: memberId,
                    role: memberRole,
                    walletManager: walletManager
                )

            case .removeMember:
                let desc = description.isEmpty
                    ? "Remove \(memberId) from \(memberRole)"
                    : description
                _ = try await treasuryService.createRemoveMemberProposal(
                    description: desc,
                    memberId: memberId,
                    role: memberRole,
                    walletManager: walletManager
                )
            }

            dismiss()
        } catch {
            self.error = error.localizedDescription
        }

        isSubmitting = false
    }
}
