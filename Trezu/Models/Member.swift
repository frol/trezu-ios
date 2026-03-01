import Foundation

// MARK: - Member

struct Member: Identifiable, Hashable {
    var id: String { accountId }
    let accountId: String
    let roles: [String]

    var isGovernance: Bool { roles.contains("Governance") }
    var isFinancial: Bool { roles.contains("Financial") }
    var isRequestor: Bool { roles.contains("Requestor") }

    var roleDisplayString: String {
        roles.joined(separator: ", ")
    }
}

// MARK: - UserProfile

struct UserProfile: Codable {
    let accountId: String?
    let name: String?
    let image: ProfileImage?

    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case name, image
    }
}

struct ProfileImage: Codable {
    let url: String?
    let ipfsCid: String?

    enum CodingKeys: String, CodingKey {
        case url
        case ipfsCid = "ipfs_cid"
    }

    var imageURL: URL? {
        if let url = url {
            return URL(string: url)
        }
        if let cid = ipfsCid {
            return URL(string: "https://ipfs.near.social/ipfs/\(cid)")
        }
        return nil
    }
}

// MARK: - AuthUser

struct AuthUser: Codable {
    let accountId: String
    let termsAccepted: Bool?
}

// MARK: - AuthChallenge

struct AuthChallenge: Codable {
    let nonce: String
    // message and recipient are app-level constants, not returned by the server
    var message: String { "Login to Trezu" }
    var recipient: String { "Trezu App" }
}
