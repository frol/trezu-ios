import Foundation

struct Member: Codable, Identifiable, Hashable {
    let accountId: String
    let roles: [String]

    var id: String { accountId }

    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case roles
    }

    var displayName: String {
        if accountId.count > 20 {
            let start = accountId.prefix(8)
            let end = accountId.suffix(6)
            return "\(start)...\(end)"
        }
        return accountId
    }
}

struct MembersResponse: Codable {
    let members: [Member]
}

struct UserProfile: Codable {
    let accountId: String
    let name: String?
    let description: String?
    let image: ProfileImage?
    let backgroundImage: ProfileImage?
    let linktree: [String: String]?
    let tags: [String: String]?

    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case name
        case description
        case image
        case backgroundImage
        case linktree
        case tags
    }
}

struct ProfileImage: Codable {
    let ipfsCid: String?
    let url: String?

    enum CodingKeys: String, CodingKey {
        case ipfsCid = "ipfs_cid"
        case url
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
