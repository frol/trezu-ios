import SwiftUI
import NEARConnect

struct SettingsView: View {
    @Environment(AuthService.self) private var authService
    @Environment(TreasuryService.self) private var treasuryService
    @EnvironmentObject private var walletManager: NEARWalletManager

    var body: some View {
        NavigationStack {
            List {
                // Treasury Info
                if let treasury = treasuryService.selectedTreasury {
                    Section("Treasury") {
                        LabeledContent("Name", value: treasury.name)
                        LabeledContent("DAO ID", value: treasury.daoId)
                        if let purpose = treasury.purpose, !purpose.isEmpty {
                            LabeledContent("Purpose", value: purpose)
                        }
                    }
                }

                // Policy Info
                if let policy = treasuryService.policy {
                    Section("Governance Policy") {
                        LabeledContent("Roles") {
                            Text("\(policy.roles.count)")
                        }

                        if let bond = policy.proposalBond {
                            LabeledContent("Proposal Bond") {
                                Text("\(formatNEAR(bond)) NEAR")
                            }
                        }

                        if let period = policy.proposalPeriod {
                            LabeledContent("Proposal Period") {
                                Text(formatNanoDuration(period))
                            }
                        }
                    }

                    Section("Role Permissions") {
                        ForEach(policy.roles) { role in
                            DisclosureGroup {
                                if let permissions = role.permissions {
                                    ForEach(permissions, id: \.self) { perm in
                                        Text(perm)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                let memberCount = role.kind.memberAccounts.count
                                if memberCount > 0 {
                                    LabeledContent("Members") {
                                        Text("\(memberCount)")
                                    }
                                }
                            } label: {
                                HStack {
                                    RoleBadge(role: role.name)
                                    Spacer()
                                }
                            }
                        }
                    }
                }

                // Account section
                Section("Account") {
                    if let user = authService.currentUser {
                        LabeledContent("Account", value: user.accountId)
                    }
                }

                // Actions
                Section {
                    Button {
                        treasuryService.selectedTreasury = nil
                    } label: {
                        Label("Switch Treasury", systemImage: "arrow.triangle.2.circlepath")
                    }

                    Button(role: .destructive) {
                        Task { await authService.signOut(walletManager: walletManager) }
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Duration Formatter

func formatNanoDuration(_ nanos: String) -> String {
    guard let nanosDouble = Double(nanos) else { return nanos }
    let seconds = nanosDouble / 1_000_000_000
    let days = Int(seconds / 86400)
    let hours = Int(seconds.truncatingRemainder(dividingBy: 86400) / 3600)

    if days > 0 {
        return hours > 0 ? "\(days)d \(hours)h" : "\(days)d"
    } else if hours > 0 {
        return "\(hours)h"
    } else {
        let mins = Int(seconds / 60)
        return "\(mins)m"
    }
}
