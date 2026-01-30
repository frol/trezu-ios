import Foundation
import SwiftUI

struct WalletAccount: Codable, Identifiable, Hashable {
    let accountId: String

    var id: String { accountId }

    enum CodingKeys: String, CodingKey {
        case accountId = "accountId"
    }

    init(accountId: String) {
        self.accountId = accountId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            self.accountId = stringValue
        } else {
            let dict = try decoder.container(keyedBy: CodingKeys.self)
            self.accountId = try dict.decode(String.self, forKey: .accountId)
        }
    }
}

struct WalletTransaction: Codable {
    let receiverId: String
    let actions: [WalletAction]

    enum CodingKeys: String, CodingKey {
        case receiverId = "receiverId"
        case actions
    }
}

enum WalletAction: Codable {
    case functionCall(FunctionCallAction)
    case transfer(TransferAction)

    struct FunctionCallAction: Codable {
        let methodName: String
        let args: [String: AnyCodable]
        let gas: String
        let deposit: String

        enum CodingKeys: String, CodingKey {
            case methodName = "methodName"
            case args
            case gas
            case deposit
        }
    }

    struct TransferAction: Codable {
        let deposit: String
    }

    enum CodingKeys: String, CodingKey {
        case type
        case params
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "FunctionCall":
            let action = try container.decode(FunctionCallAction.self, forKey: .params)
            self = .functionCall(action)
        case "Transfer":
            let action = try container.decode(TransferAction.self, forKey: .params)
            self = .transfer(action)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown action type: \(type)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .functionCall(let action):
            try container.encode("FunctionCall", forKey: .type)
            try container.encode(action, forKey: .params)
        case .transfer(let action):
            try container.encode("Transfer", forKey: .type)
            try container.encode(action, forKey: .params)
        }
    }
}

struct TransactionResult: Codable {
    let transactionHash: String?
    let status: TransactionStatus?

    enum CodingKeys: String, CodingKey {
        case transactionHash = "transaction_hash"
        case status
    }
}

struct TransactionStatus: Codable {
    let successValue: String?
    let failure: AnyCodable?

    enum CodingKeys: String, CodingKey {
        case successValue = "SuccessValue"
        case failure = "Failure"
    }
}

enum WalletError: Error, LocalizedError {
    case notInitialized
    case notConnected
    case connectionFailed(String)
    case transactionFailed(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Wallet not initialized"
        case .notConnected:
            return "Wallet not connected"
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .transactionFailed(let message):
            return "Transaction failed: \(message)"
        case .timeout:
            return "Operation timed out"
        }
    }
}

@Observable
final class WalletManager {
    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected(accountId: String)

        static func == (lhs: ConnectionState, rhs: ConnectionState) -> Bool {
            switch (lhs, rhs) {
            case (.disconnected, .disconnected):
                return true
            case (.connecting, .connecting):
                return true
            case (.connected(let a), .connected(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    static let shared = WalletManager()

    private(set) var state: ConnectionState = .disconnected
    private(set) var accounts: [WalletAccount] = []
    private(set) var isReady = false
    private(set) var lastError: String?

    var isConnected: Bool {
        if case .connected = state { return true }
        return false
    }

    var currentAccountId: String? {
        if case .connected(let accountId) = state { return accountId }
        return nil
    }

    weak var webView: NearConnectWebView?

    private init() {
        loadPersistedState()
    }

    // MARK: - State Persistence

    private let accountIdKey = "NearTreasury.AccountId"

    private func loadPersistedState() {
        if let accountId = UserDefaults.standard.string(forKey: accountIdKey) {
            state = .connected(accountId: accountId)
            accounts = [WalletAccount(accountId: accountId)]
        }
    }

    private func persistState() {
        if case .connected(let accountId) = state {
            UserDefaults.standard.set(accountId, forKey: accountIdKey)
        } else {
            UserDefaults.standard.removeObject(forKey: accountIdKey)
        }
    }

    // MARK: - Connection Management

    func handleReady() {
        isReady = true
    }

    func handleSignIn(accounts: [WalletAccount]) {
        self.accounts = accounts
        if let firstAccount = accounts.first {
            state = .connected(accountId: firstAccount.accountId)
            persistState()
        }
    }

    func handleSignOut() {
        accounts = []
        state = .disconnected
        persistState()
    }

    func handleError(message: String) {
        lastError = message
        if state == .connecting {
            state = .disconnected
        }
    }

    func connect() async throws {
        guard isReady else {
            throw WalletError.notInitialized
        }

        state = .connecting
        lastError = nil

        await webView?.connect()
    }

    func disconnect() async throws {
        guard isConnected else { return }

        await webView?.disconnect()
        handleSignOut()
    }

    func signAndSendTransactions(_ transactions: [WalletTransaction]) async throws -> [TransactionResult] {
        guard isConnected else {
            throw WalletError.notConnected
        }

        guard let webView = webView else {
            throw WalletError.notInitialized
        }

        let result = try await webView.signAndSendTransactions(transactions)
        return result
    }

    func signAndSendTransaction(_ transaction: WalletTransaction) async throws -> TransactionResult {
        let results = try await signAndSendTransactions([transaction])
        guard let result = results.first else {
            throw WalletError.transactionFailed("No result returned")
        }
        return result
    }
}
