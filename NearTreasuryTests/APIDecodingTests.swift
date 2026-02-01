import XCTest
@testable import NearTreasury

/// Tests for decoding API responses correctly
/// These tests verify that our model structures match the actual API responses
final class APIDecodingTests: XCTestCase {

    let decoder = JSONDecoder()

    // MARK: - Treasury Decoding

    func testDecodeTreasuryArray() throws {
        let json = """
        [
            {
                "daoId": "test.sputnik-dao.near",
                "config": {
                    "metadata": {"primaryColor": "#EF4444", "flagLogo": ""},
                    "name": "Test Treasury",
                    "purpose": "Testing"
                }
            }
        ]
        """.data(using: .utf8)!

        let treasuries = try decoder.decode([Treasury].self, from: json)
        XCTAssertEqual(treasuries.count, 1)
        XCTAssertEqual(treasuries[0].daoId, "test.sputnik-dao.near")
        XCTAssertEqual(treasuries[0].config?.name, "Test Treasury")
    }

    func testDecodeTreasuryWithNullMetadata() throws {
        let json = """
        [
            {
                "daoId": "test.sputnik-dao.near",
                "config": {
                    "metadata": null,
                    "name": "Test",
                    "purpose": ""
                }
            }
        ]
        """.data(using: .utf8)!

        let treasuries = try decoder.decode([Treasury].self, from: json)
        XCTAssertEqual(treasuries.count, 1)
        XCTAssertNil(treasuries[0].config?.metadata)
    }

    // MARK: - Asset Decoding

    func testDecodeAssetArray() throws {
        let json = """
        [
            {
                "id": "wrap.near",
                "contractId": "wrap.near",
                "symbol": "wNEAR",
                "name": "Wrapped NEAR",
                "decimals": 24,
                "balance": "1000000000000000000000000",
                "price": "5.25",
                "icon": null,
                "network": "near",
                "chainName": "NEAR",
                "residency": "Ft"
            }
        ]
        """.data(using: .utf8)!

        let assets = try decoder.decode([TreasuryAsset].self, from: json)
        XCTAssertEqual(assets.count, 1)
        XCTAssertEqual(assets[0].symbol, "wNEAR")
        XCTAssertEqual(assets[0].decimals, 24)
    }

    // MARK: - Proposal Decoding

    func testDecodeProposalWithTransfer() throws {
        let json = """
        {
            "proposals": [
                {
                    "id": 1,
                    "proposer": "alice.near",
                    "description": "Transfer funds",
                    "kind": {
                        "Transfer": {
                            "token_id": "",
                            "receiver_id": "bob.near",
                            "amount": "1000000000000000000000000"
                        }
                    },
                    "status": "Approved",
                    "vote_counts": {"council": [2, 0, 0]},
                    "votes": {"alice.near": "Approve"},
                    "submission_time": 1710256458583110519
                }
            ],
            "total": 1
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(ProposalsResponse.self, from: json)
        XCTAssertEqual(response.proposals.count, 1)
        XCTAssertEqual(response.proposals[0].status, .approved)

        if case .transfer(let kind) = response.proposals[0].kind {
            XCTAssertEqual(kind.receiverId, "bob.near")
        } else {
            XCTFail("Expected transfer kind")
        }
    }

    func testDecodeProposalWithFunctionCall() throws {
        let json = """
        {
            "proposals": [
                {
                    "id": 3,
                    "proposer": "alice.near",
                    "description": "Call function",
                    "kind": {
                        "FunctionCall": {
                            "receiver_id": "social.near",
                            "actions": [
                                {
                                    "method_name": "set",
                                    "args": "eyJkYXRhIjp7fX0=",
                                    "deposit": "100000000000000000000000",
                                    "gas": "200000000000000"
                                }
                            ]
                        }
                    },
                    "status": "InProgress",
                    "vote_counts": {},
                    "votes": {},
                    "submission_time": 1710256458583110519
                }
            ],
            "total": 1
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(ProposalsResponse.self, from: json)
        XCTAssertEqual(response.proposals.count, 1)

        if case .functionCall(let kind) = response.proposals[0].kind {
            XCTAssertEqual(kind.receiverId, "social.near")
            XCTAssertEqual(kind.methodName, "set")
        } else {
            XCTFail("Expected functionCall kind")
        }
    }

    func testDecodeProposalWithVoteKind() throws {
        let json = """
        {
            "proposals": [
                {
                    "id": 10,
                    "proposer": "alice.near",
                    "description": "Vote",
                    "kind": "Vote",
                    "status": "Approved",
                    "vote_counts": {"council": [1, 0, 0]},
                    "votes": {},
                    "submission_time": 1710256458583110519
                }
            ],
            "total": 1
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(ProposalsResponse.self, from: json)
        XCTAssertEqual(response.proposals.count, 1)

        if case .vote = response.proposals[0].kind {
            // Success
        } else {
            XCTFail("Expected vote kind, got \(response.proposals[0].kind)")
        }
    }

    func testDecodeProposalWithChangePolicy() throws {
        let json = """
        {
            "proposals": [
                {
                    "id": 0,
                    "proposer": "alice.near",
                    "description": "Update policy",
                    "kind": {
                        "ChangePolicy": {
                            "policy": {
                                "roles": [],
                                "default_vote_policy": {}
                            }
                        }
                    },
                    "status": "Approved",
                    "vote_counts": {"council": [1, 0, 0]},
                    "votes": {},
                    "submission_time": 1710256458583110519
                }
            ],
            "total": 1
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(ProposalsResponse.self, from: json)
        XCTAssertEqual(response.proposals.count, 1)

        if case .changePolicy = response.proposals[0].kind {
            // Success
        } else {
            XCTFail("Expected changePolicy kind")
        }
    }

    func testDecodeProposalWithAddMember() throws {
        let json = """
        {
            "proposals": [
                {
                    "id": 5,
                    "proposer": "alice.near",
                    "description": "Add member",
                    "kind": {
                        "AddMemberToRole": {
                            "member_id": "bob.near",
                            "role": "council"
                        }
                    },
                    "status": "InProgress",
                    "vote_counts": {},
                    "votes": {},
                    "submission_time": 1710256458583110519
                }
            ],
            "total": 1
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(ProposalsResponse.self, from: json)
        if case .addMemberToRole(let kind) = response.proposals[0].kind {
            XCTAssertEqual(kind.memberId, "bob.near")
            XCTAssertEqual(kind.role, "council")
        } else {
            XCTFail("Expected addMemberToRole kind")
        }
    }

    // MARK: - Policy Decoding

    func testDecodePolicy() throws {
        let json = """
        {
            "bounty_bond": "100000000000000000000000",
            "bounty_forgiveness_period": "604800000000000",
            "default_vote_policy": {
                "quorum": "0",
                "threshold": [1, 2],
                "weight_kind": "RoleWeight"
            },
            "proposal_bond": "100000000000000000000000",
            "proposal_period": "604800000000000",
            "roles": [
                {
                    "kind": {"Group": ["alice.near", "bob.near"]},
                    "name": "council",
                    "permissions": ["*:*"]
                }
            ]
        }
        """.data(using: .utf8)!

        let policy = try decoder.decode(Policy.self, from: json)
        XCTAssertEqual(policy.roles.count, 1)
        XCTAssertEqual(policy.roles[0].name, "council")

        let members = policy.allMembers
        XCTAssertEqual(members.count, 2)
    }

    // MARK: - Activity Decoding

    func testDecodeRecentActivity() throws {
        let json = """
        {
            "data": [
                {
                    "id": 12345,
                    "block_time": "2024-01-15T10:30:00.000000Z",
                    "token_id": "wrap.near",
                    "token_metadata": {
                        "tokenId": "wrap.near",
                        "name": "Wrapped NEAR",
                        "symbol": "wNEAR",
                        "decimals": 24,
                        "icon": null
                    },
                    "counterparty": "bob.near",
                    "signer_id": "alice.near",
                    "receiver_id": "bob.near",
                    "amount": "1000000000000000000000000",
                    "transaction_hashes": ["abc123"]
                }
            ],
            "total": 100
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(RecentActivityResponse.self, from: json)
        XCTAssertEqual(response.activities.count, 1)
        XCTAssertEqual(response.activities[0].id, 12345)
        XCTAssertEqual(response.activities[0].tokenMetadata?.symbol, "wNEAR")
    }

    func testDecodeActivityWithStakingReward() throws {
        let json = """
        {
            "data": [
                {
                    "id": 41519,
                    "block_time": "2024-01-30T02:40:22.002665Z",
                    "token_id": "staking:figment.poolv1.near",
                    "token_metadata": {
                        "tokenId": "staking:figment.poolv1.near",
                        "name": "STAKING:FIGMENT",
                        "symbol": "STAKING:FIGMENT",
                        "decimals": 18,
                        "icon": null
                    },
                    "counterparty": "STAKING_REWARD",
                    "signer_id": null,
                    "receiver_id": null,
                    "amount": "1.27317361331416E-10",
                    "transaction_hashes": []
                }
            ],
            "total": 1039
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(RecentActivityResponse.self, from: json)
        XCTAssertEqual(response.activities[0].counterparty, "STAKING_REWARD")
        XCTAssertEqual(response.activities[0].actionDescription, "Staking Reward")
    }

    // MARK: - Vote Counts Decoding

    func testDecodeVoteCountsWithThreeValues() throws {
        let json = """
        {
            "proposals": [
                {
                    "id": 1,
                    "proposer": "alice.near",
                    "description": "Test",
                    "kind": {"Transfer": {"token_id": "", "receiver_id": "bob.near", "amount": "1"}},
                    "status": "Approved",
                    "vote_counts": {"council": [2, 1, 0]},
                    "votes": {},
                    "submission_time": 1710256458583110519
                }
            ],
            "total": 1
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(ProposalsResponse.self, from: json)
        XCTAssertEqual(response.proposals[0].approveCount, 2)
        XCTAssertEqual(response.proposals[0].rejectCount, 1)
    }

    func testDecodeEmptyVoteCounts() throws {
        let json = """
        {
            "proposals": [
                {
                    "id": 1,
                    "proposer": "alice.near",
                    "description": "Test",
                    "kind": {"Transfer": {"token_id": "", "receiver_id": "bob.near", "amount": "1"}},
                    "status": "InProgress",
                    "vote_counts": {},
                    "votes": {},
                    "submission_time": 1710256458583110519
                }
            ],
            "total": 1
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(ProposalsResponse.self, from: json)
        XCTAssertEqual(response.proposals[0].approveCount, 0)
        XCTAssertEqual(response.proposals[0].rejectCount, 0)
    }
}
