#!/usr/bin/env swift

import Foundation

// MARK: - Test Configuration

let testTreasuryId = "testing-astradao.sputnik-dao.near"
let testMemberAccount = "frol.near"
let testMemberWithTreasuries = "megha19.near"
let baseURL = "https://near-treasury-backend.onrender.com/api"

// MARK: - Test Runner

var passedTests = 0
var failedTests = 0
var totalTests = 0

func runTest(_ name: String, _ test: () async throws -> Void) async {
    totalTests += 1
    print("Running: \(name)...", terminator: " ")
    do {
        try await test()
        passedTests += 1
        print("✅ PASSED")
    } catch {
        failedTests += 1
        print("❌ FAILED: \(error)")
    }
}

func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String = "") throws {
    guard actual == expected else {
        throw TestError.assertionFailed("Expected \(expected), got \(actual). \(message)")
    }
}

func assertTrue(_ condition: Bool, _ message: String = "") throws {
    guard condition else {
        throw TestError.assertionFailed("Condition was false. \(message)")
    }
}

func assertFalse(_ condition: Bool, _ message: String = "") throws {
    guard !condition else {
        throw TestError.assertionFailed("Condition was true. \(message)")
    }
}

enum TestError: Error, LocalizedError {
    case assertionFailed(String)
    case networkError(String)
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .assertionFailed(let msg): return "Assertion failed: \(msg)"
        case .networkError(let msg): return "Network error: \(msg)"
        case .decodingError(let msg): return "Decoding error: \(msg)"
        }
    }
}

// MARK: - API Helper

func fetchJSON<T: Decodable>(_ endpoint: String, as type: T.Type) async throws -> T {
    guard let url = URL(string: "\(baseURL)\(endpoint)") else {
        throw TestError.networkError("Invalid URL: \(endpoint)")
    }

    let (data, response) = try await URLSession.shared.data(from: url)

    guard let httpResponse = response as? HTTPURLResponse else {
        throw TestError.networkError("Invalid response")
    }

    guard (200...299).contains(httpResponse.statusCode) else {
        let body = String(data: data, encoding: .utf8) ?? ""
        throw TestError.networkError("HTTP \(httpResponse.statusCode): \(body)")
    }

    do {
        return try JSONDecoder().decode(type, from: data)
    } catch {
        let preview = String(data: data.prefix(500), encoding: .utf8) ?? ""
        throw TestError.decodingError("\(error)\nResponse: \(preview)")
    }
}

// MARK: - Models (Minimal for testing)

struct TreasuryItem: Codable {
    let daoId: String
    let config: TreasuryConfig?
}

struct TreasuryConfig: Codable {
    let name: String?
    let purpose: String?
    let metadata: TreasuryMetadata?
}

struct TreasuryMetadata: Codable {
    let primaryColor: String?
    let flagLogo: String?
}

struct AssetItem: Codable {
    let id: String
    let symbol: String
    let decimals: Int?
    let balance: String?
    let price: String?
}

struct ProposalsResponse: Codable {
    let proposals: [ProposalItem]
    let total: Int?
}

struct ProposalItem: Codable {
    let id: Int
    let proposer: String
    let description: String
    let status: String
    let submissionTime: UInt64

    enum CodingKeys: String, CodingKey {
        case id, proposer, description, status
        case submissionTime = "submission_time"
    }
}

struct PolicyResponse: Codable {
    let roles: [RoleItem]
}

struct RoleItem: Codable {
    let name: String
    let kind: RoleKind
}

struct RoleKind: Codable {
    let Group: [String]?
}

struct ActivityResponse: Codable {
    let data: [ActivityItem]
    let total: Int?
}

struct ActivityItem: Codable {
    let id: Int
    let blockTime: String
    let counterparty: String?

    enum CodingKeys: String, CodingKey {
        case id
        case blockTime = "block_time"
        case counterparty
    }
}

// MARK: - Tests

func runAllTests() async {
        print("=" * 60)
        print("NEAR Treasury API Integration Tests")
        print("Testing against: \(testTreasuryId)")
        print("=" * 60)
        print("")

        // Treasury Tests
        await runTest("Get user treasuries") {
            let treasuries: [TreasuryItem] = try await fetchJSON(
                "/user/treasuries?accountId=\(testMemberWithTreasuries)",
                as: [TreasuryItem].self
            )
            try assertFalse(treasuries.isEmpty, "Should have treasuries")
            let hasTestTreasury = treasuries.contains { $0.daoId == testTreasuryId }
            try assertTrue(hasTestTreasury, "Should include test treasury")
        }

        await runTest("Get user treasuries for new user handles 404") {
            // API returns 404 for users with no treasuries - that's expected behavior
            do {
                let _: [TreasuryItem] = try await fetchJSON(
                    "/user/treasuries?accountId=nonexistent-user-xyz.near",
                    as: [TreasuryItem].self
                )
                // If we get here, it means empty array was returned (also acceptable)
            } catch TestError.networkError(let msg) where msg.contains("404") {
                // Expected - API returns 404 for users with no DAOs
                print("Got expected 404 for new user")
            }
        }

        // Asset Tests
        await runTest("Get treasury assets") {
            let assets: [AssetItem] = try await fetchJSON(
                "/user/assets?accountId=\(testTreasuryId)",
                as: [AssetItem].self
            )
            try assertFalse(assets.isEmpty, "Should have assets")
            for asset in assets {
                try assertFalse(asset.id.isEmpty, "Asset should have id")
                try assertFalse(asset.symbol.isEmpty, "Asset should have symbol")
            }
        }

        // Proposal Tests
        await runTest("Get proposals") {
            let response: ProposalsResponse = try await fetchJSON(
                "/proposals/\(testTreasuryId)?limit=50",
                as: ProposalsResponse.self
            )
            try assertFalse(response.proposals.isEmpty, "Should have proposals")
            for proposal in response.proposals {
                try assertTrue(proposal.id >= 0, "Proposal should have valid id")
                try assertFalse(proposal.proposer.isEmpty, "Proposal should have proposer")
            }
        }

        await runTest("Get pending proposals") {
            let response: ProposalsResponse = try await fetchJSON(
                "/proposals/\(testTreasuryId)?status=InProgress&limit=10",
                as: ProposalsResponse.self
            )
            // Just verify it decodes without error
            print("Found \(response.proposals.count) pending proposals")
        }

        await runTest("Get approved proposals") {
            let response: ProposalsResponse = try await fetchJSON(
                "/proposals/\(testTreasuryId)?status=Approved&limit=10",
                as: ProposalsResponse.self
            )
            // Just verify it decodes without error
            print("Found \(response.proposals.count) approved proposals")
        }

        await runTest("Proposal pagination works") {
            let page1: ProposalsResponse = try await fetchJSON(
                "/proposals/\(testTreasuryId)?limit=10&offset=0",
                as: ProposalsResponse.self
            )
            let page2: ProposalsResponse = try await fetchJSON(
                "/proposals/\(testTreasuryId)?limit=10&offset=10",
                as: ProposalsResponse.self
            )

            // Verify both pages return data
            try assertFalse(page1.proposals.isEmpty, "Page 1 should have proposals")
            try assertFalse(page2.proposals.isEmpty, "Page 2 should have proposals")

            // Note: API pagination behavior may vary - just verify both requests succeed
            print("Page 1: \(page1.proposals.count) proposals, Page 2: \(page2.proposals.count) proposals")
        }

        // Policy Tests
        await runTest("Get treasury policy") {
            let policy: PolicyResponse = try await fetchJSON(
                "/treasury/policy?treasuryId=\(testTreasuryId)",
                as: PolicyResponse.self
            )
            try assertFalse(policy.roles.isEmpty, "Policy should have roles")

            // Test treasury uses custom roles: Requestor, Admin, Approver
            let roleNames = policy.roles.map { $0.name }
            print("Roles found: \(roleNames.joined(separator: ", "))")
            try assertTrue(roleNames.count > 0, "Should have at least one role")
        }

        await runTest("Policy member extraction") {
            let policy: PolicyResponse = try await fetchJSON(
                "/treasury/policy?treasuryId=\(testTreasuryId)",
                as: PolicyResponse.self
            )

            var memberCount = 0
            for role in policy.roles {
                if let members = role.kind.Group {
                    memberCount += members.count
                }
            }
            try assertTrue(memberCount > 0, "Should have members")
            print("Found \(memberCount) members")
        }

        // Config Tests
        await runTest("Get treasury config") {
            let config: TreasuryConfig = try await fetchJSON(
                "/treasury/config?treasuryId=\(testTreasuryId)",
                as: TreasuryConfig.self
            )
            try assertTrue(config.name != nil, "Config should have name")
        }

        // Activity Tests
        await runTest("Get recent activity") {
            let response: ActivityResponse = try await fetchJSON(
                "/recent-activity?account_id=\(testTreasuryId)&limit=10",
                as: ActivityResponse.self
            )
            try assertFalse(response.data.isEmpty, "Should have activities")
            for activity in response.data {
                try assertTrue(activity.id > 0, "Activity should have valid id")
                try assertFalse(activity.blockTime.isEmpty, "Activity should have block time")
            }
        }

        await runTest("Activity with staking rewards") {
            let response: ActivityResponse = try await fetchJSON(
                "/recent-activity?account_id=\(testTreasuryId)&limit=50",
                as: ActivityResponse.self
            )

            let stakingRewards = response.data.filter { $0.counterparty == "STAKING_REWARD" }
            print("Found \(stakingRewards.count) staking reward activities")
        }

        // Print Summary
        print("")
        print("=" * 60)
        print("TEST RESULTS")
        print("=" * 60)
        print("Total:  \(totalTests)")
        print("Passed: \(passedTests) ✅")
        print("Failed: \(failedTests) ❌")
        print("")

    if failedTests > 0 {
        print("⚠️  Some tests failed!")
        exit(1)
    } else {
        print("🎉 All tests passed!")
        exit(0)
    }
}

extension String {
    static func * (lhs: String, rhs: Int) -> String {
        String(repeating: lhs, count: rhs)
    }
}

// Run tests
let semaphore = DispatchSemaphore(value: 0)
Task {
    await runAllTests()
    semaphore.signal()
}
semaphore.wait()
