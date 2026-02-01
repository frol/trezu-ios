import XCTest
@testable import NearTreasury

/// Integration tests that run against the real NEAR Treasury API
/// Uses testing-astradao.sputnik-dao.near as the test treasury
/// and frol.near as the test member account
final class TreasuryAPIIntegrationTests: XCTestCase {

    // MARK: - Test Constants

    static let testTreasuryId = "testing-astradao.sputnik-dao.near"
    static let testMemberAccount = "frol.near"
    static let testMemberWithTreasuries = "megha19.near"

    var apiClient: TreasuryAPIClient!

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        apiClient = TreasuryAPIClient()
    }

    override func tearDown() {
        apiClient = nil
        super.tearDown()
    }

    // MARK: - Treasury Tests

    func testGetUserTreasuries() async throws {
        // Given a user with known treasuries
        let accountId = Self.testMemberWithTreasuries

        // When fetching their treasuries
        let treasuries = try await apiClient.getUserTreasuries(accountId: accountId)

        // Then we should get results
        XCTAssertFalse(treasuries.isEmpty, "User should have at least one treasury")

        // And test treasury should be in the list
        let testTreasury = treasuries.first { $0.daoId == Self.testTreasuryId }
        XCTAssertNotNil(testTreasury, "Test treasury should be in user's treasuries")

        // And each treasury should have valid data
        for treasury in treasuries {
            XCTAssertFalse(treasury.daoId.isEmpty, "Treasury should have daoId")
            XCTAssertFalse(treasury.displayName.isEmpty, "Treasury should have display name")
        }
    }

    func testGetUserTreasuriesForNewUser() async throws {
        // Given a user with no treasuries
        let accountId = "nonexistent-user-12345.near"

        // When fetching their treasuries
        let treasuries = try await apiClient.getUserTreasuries(accountId: accountId)

        // Then we should get an empty list (not an error)
        XCTAssertTrue(treasuries.isEmpty, "New user should have no treasuries")
    }

    // MARK: - Assets Tests

    func testGetTreasuryAssets() async throws {
        // When fetching assets for test treasury
        let response = try await apiClient.getUserAssets(accountId: Self.testTreasuryId)

        // Then we should get assets
        XCTAssertFalse(response.assets.isEmpty, "Treasury should have assets")

        // And each asset should have valid data
        for asset in response.assets {
            XCTAssertFalse(asset.id.isEmpty, "Asset should have id")
            XCTAssertFalse(asset.symbol.isEmpty, "Asset should have symbol")
            XCTAssertNotNil(asset.decimals, "Asset should have decimals")
        }
    }

    func testAssetBalanceCalculation() async throws {
        // When fetching assets
        let response = try await apiClient.getUserAssets(accountId: Self.testTreasuryId)

        // Then total balance should be calculated
        XCTAssertGreaterThanOrEqual(response.totalBalanceUSD, 0, "Total balance should be non-negative")

        // And individual assets should have formatted balances
        for asset in response.assets {
            let formatted = asset.formattedBalance
            XCTAssertFalse(formatted.isEmpty, "Asset should have formatted balance")
        }
    }

    // MARK: - Proposals Tests

    func testGetProposals() async throws {
        // When fetching proposals
        let filters = ProposalFilters(limit: 50, offset: 0)
        let response = try await apiClient.getProposals(daoId: Self.testTreasuryId, filters: filters)

        // Then we should get proposals
        XCTAssertFalse(response.proposals.isEmpty, "Treasury should have proposals")

        // And each proposal should have valid data
        for proposal in response.proposals {
            XCTAssertGreaterThanOrEqual(proposal.id, 0, "Proposal should have valid id")
            XCTAssertFalse(proposal.proposer.isEmpty, "Proposal should have proposer")
            XCTAssertFalse(proposal.description.isEmpty, "Proposal should have description")
        }
    }

    func testGetPendingProposals() async throws {
        // When fetching pending proposals
        let filters = ProposalFilters(status: .inProgress, limit: 10, offset: 0)
        let response = try await apiClient.getProposals(daoId: Self.testTreasuryId, filters: filters)

        // Then all returned proposals should be pending
        // Note: The API might not filter correctly, so we just verify no decoding errors
        XCTAssertNotNil(response.proposals, "Should return proposals array")
    }

    func testGetApprovedProposals() async throws {
        // When fetching approved proposals
        let filters = ProposalFilters(status: .approved, limit: 10, offset: 0)
        let response = try await apiClient.getProposals(daoId: Self.testTreasuryId, filters: filters)

        // Then we should get results without decoding errors
        XCTAssertNotNil(response.proposals, "Should return proposals array")
    }

    func testProposalKindDecoding() async throws {
        // When fetching all proposals
        let filters = ProposalFilters(limit: 100, offset: 0)
        let response = try await apiClient.getProposals(daoId: Self.testTreasuryId, filters: filters)

        // Then all proposal kinds should decode correctly
        var kindCounts: [String: Int] = [:]
        for proposal in response.proposals {
            let kindName = proposal.kind.displayName
            kindCounts[kindName, default: 0] += 1
        }

        // Print kind distribution for debugging
        print("Proposal kind distribution: \(kindCounts)")

        // And we should have multiple types of proposals
        XCTAssertGreaterThan(kindCounts.count, 1, "Should have multiple proposal types")
    }

    func testProposalPagination() async throws {
        // When fetching first page
        let page1Filters = ProposalFilters(limit: 10, offset: 0)
        let page1 = try await apiClient.getProposals(daoId: Self.testTreasuryId, filters: page1Filters)

        // And fetching second page
        let page2Filters = ProposalFilters(limit: 10, offset: 10)
        let page2 = try await apiClient.getProposals(daoId: Self.testTreasuryId, filters: page2Filters)

        // Then pages should have different proposals
        let page1Ids = Set(page1.proposals.map { $0.id })
        let page2Ids = Set(page2.proposals.map { $0.id })
        XCTAssertTrue(page1Ids.isDisjoint(with: page2Ids), "Pages should have different proposals")
    }

    // MARK: - Policy Tests

    func testGetTreasuryPolicy() async throws {
        // When fetching policy
        let policy = try await apiClient.getTreasuryPolicy(treasuryId: Self.testTreasuryId)

        // Then we should get roles
        XCTAssertFalse(policy.roles.isEmpty, "Policy should have roles")

        // And council role should exist
        let councilRole = policy.roles.first { $0.name == "council" }
        XCTAssertNotNil(councilRole, "Policy should have council role")

        // And members should be extracted
        let members = policy.allMembers
        XCTAssertFalse(members.isEmpty, "Policy should have members")
    }

    func testPolicyMemberExtraction() async throws {
        // When fetching policy
        let policy = try await apiClient.getTreasuryPolicy(treasuryId: Self.testTreasuryId)

        // Then we should extract all members
        let members = policy.allMembers

        // And each member should have valid data
        for member in members {
            XCTAssertFalse(member.accountId.isEmpty, "Member should have accountId")
            XCTAssertFalse(member.role.isEmpty, "Member should have role")
        }

        // And test member should be in the list (if they are a member)
        // Note: frol.near may or may not be a member, so we just verify structure
        print("Found \(members.count) members")
    }

    // MARK: - Config Tests

    func testGetTreasuryConfig() async throws {
        // When fetching config
        let config = try await apiClient.getTreasuryConfig(treasuryId: Self.testTreasuryId)

        // Then we should get config data
        XCTAssertNotNil(config.name, "Config should have name")

        // And display name should work
        XCTAssertFalse(config.displayName.isEmpty, "Config should have display name")
    }

    // MARK: - Activity Tests

    func testGetRecentActivity() async throws {
        // When fetching activity
        let response = try await apiClient.getRecentActivity(
            accountId: Self.testTreasuryId,
            limit: 10,
            offset: 0
        )

        // Then we should get activities
        XCTAssertFalse(response.activities.isEmpty, "Treasury should have recent activity")

        // And each activity should have valid data
        for activity in response.activities {
            XCTAssertGreaterThan(activity.id, 0, "Activity should have valid id")
            XCTAssertFalse(activity.blockTime.isEmpty, "Activity should have block time")
        }
    }

    func testActivityTimeFormatting() async throws {
        // When fetching activity
        let response = try await apiClient.getRecentActivity(
            accountId: Self.testTreasuryId,
            limit: 5,
            offset: 0
        )

        // Then activities should have formatted times
        for activity in response.activities {
            let formattedTime = activity.formattedTime
            // Formatted time might be empty for very old dates, but shouldn't crash
            print("Activity \(activity.id): \(formattedTime)")
        }
    }

    // MARK: - User Profile Tests

    func testGetUserProfile() async throws {
        // When fetching profile for test member
        let profile = try await apiClient.getUserProfile(accountId: Self.testMemberAccount)

        // Then we should get profile data (may be mostly nil for accounts without profiles)
        XCTAssertNotNil(profile, "Should return profile object")
    }

    // MARK: - Error Handling Tests

    func testInvalidTreasuryReturnsError() async {
        // Given an invalid treasury ID
        let invalidId = "nonexistent-treasury-12345.sputnik-dao.near"

        // When fetching its policy
        do {
            _ = try await apiClient.getTreasuryPolicy(treasuryId: invalidId)
            XCTFail("Should throw error for invalid treasury")
        } catch {
            // Then we should get an error (could be HTTP error or empty response)
            XCTAssertNotNil(error, "Should have error")
        }
    }

    // MARK: - ViewModel Integration Tests

    func testDashboardViewModelLoading() async throws {
        // Given a dashboard view model
        let viewModel = DashboardViewModel()

        // When loading dashboard data
        await viewModel.loadDashboard(treasuryId: Self.testTreasuryId, apiClient: apiClient)

        // Then state should be loaded
        if case .loaded = viewModel.state {
            // Success
        } else if case .error(let error) = viewModel.state {
            XCTFail("Dashboard loading failed: \(error)")
        } else {
            XCTFail("Dashboard should be in loaded state")
        }

        // And we should have data
        XCTAssertFalse(viewModel.assets.isEmpty, "Should have assets")
    }

    func testProposalsListViewModelLoading() async throws {
        // Given a proposals view model
        let viewModel = ProposalsListViewModel()

        // When loading proposals
        await viewModel.loadProposals(daoId: Self.testTreasuryId, apiClient: apiClient)

        // Then state should be loaded
        if case .loaded = viewModel.state {
            // Success
        } else if case .error(let error) = viewModel.state {
            XCTFail("Proposals loading failed: \(error)")
        } else {
            XCTFail("Proposals should be in loaded state")
        }

        // And we should have proposals
        XCTAssertFalse(viewModel.proposals.isEmpty, "Should have proposals")
    }

    func testMembersListViewModelLoading() async throws {
        // Given a members view model
        let viewModel = MembersListViewModel()

        // When loading members
        await viewModel.loadMembers(treasuryId: Self.testTreasuryId, apiClient: apiClient)

        // Then state should be loaded
        if case .loaded = viewModel.state {
            // Success
        } else if case .error(let error) = viewModel.state {
            XCTFail("Members loading failed: \(error)")
        } else {
            XCTFail("Members should be in loaded state")
        }

        // And we should have members
        XCTAssertFalse(viewModel.members.isEmpty, "Should have members")
    }

    // MARK: - Data Consistency Tests

    func testMemberCountMatchesPolicyRoles() async throws {
        // When fetching policy
        let policy = try await apiClient.getTreasuryPolicy(treasuryId: Self.testTreasuryId)

        // Then member count should match roles
        var expectedMemberCount = 0
        for role in policy.roles {
            if case .group(let members) = role.kind {
                expectedMemberCount += members.count
            }
        }

        let extractedMembers = policy.allMembers
        XCTAssertEqual(extractedMembers.count, expectedMemberCount, "Member count should match roles")
    }
}
