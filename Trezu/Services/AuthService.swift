import Foundation
import NEARConnect

// MARK: - Auth Service

/// Manages authentication flow using connectAndSignMessage for single-step sign-in.
@Observable
class AuthService {
    var currentUser: AuthUser?
    var isAuthenticated: Bool { currentUser != nil }
    var isLoading = false
    var error: String?
    var needsTermsAcceptance: Bool {
        currentUser?.termsAccepted == false
    }

    private let api = APIClient.shared

    // MARK: - Check Existing Session

    func checkSession() async {
        let user = await api.getAuthMe()
        currentUser = user
    }

    // MARK: - Sign In (connect wallet + sign message in one step)

    /// Single-step sign-in: connects wallet, signs auth challenge, and creates backend session.
    func signIn(walletManager: NEARWalletManager) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            // 1. Get authentication challenge from backend
            let challenge: AuthChallenge
            do {
                challenge = try await api.getAuthChallenge()
            } catch {
                self.error = "Failed to get auth challenge: \(error.localizedDescription)"
                return
            }

            // 2. Decode the Base64 nonce from the challenge into raw bytes.
            //    The backend generates a 32-byte random nonce and returns it as Base64.
            //    The wallet needs the raw bytes for NEP-413 signing.
            guard let nonceData = Data(base64Encoded: challenge.nonce) else {
                self.error = "Invalid nonce format from server"
                return
            }

            // 3. Connect wallet and sign the challenge message in one step.
            //    The wallet selector UI appears, user picks a wallet,
            //    approves the connection and signs the message — all in one flow.
            let result = try await walletManager.connectAndSignMessage(
                message: challenge.message,
                recipient: challenge.recipient,
                nonce: nonceData
            )

            // 4. Parse the signedMessage JSON to extract publicKey and signature.
            //    The wallet returns signedMessage as a JSON string like:
            //    {"accountId":"...","publicKey":"ed25519:...","signature":"...","nonce":"..."}
            let account = result.account
            var publicKey = account.publicKey ?? ""
            var signature = ""

            if let smString = result.signedMessage {
                if let smData = smString.data(using: .utf8),
                   let smJSON = try? JSONSerialization.jsonObject(with: smData) as? [String: Any] {
                    if let pk = smJSON["publicKey"] as? String, !pk.isEmpty {
                        publicKey = pk
                    }
                    if let sig = smJSON["signature"] as? String {
                        signature = sig
                    }
                } else {
                    signature = smString
                }
            }

            // 5. Submit to the backend for session creation
            let user = try await api.authLogin(
                accountId: account.accountId,
                publicKey: publicKey,
                signature: signature,
                message: challenge.message,
                nonce: challenge.nonce,
                recipient: challenge.recipient
            )

            currentUser = user
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Sign Out

    func signOut(walletManager: NEARWalletManager) async {
        try? await api.authLogout()
        walletManager.disconnect()
        currentUser = nil
    }

    // MARK: - Accept Terms

    func acceptTerms() async throws {
        try await api.acceptTerms()
        if let user = currentUser {
            currentUser = AuthUser(
                accountId: user.accountId,
                termsAccepted: true
            )
        }
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case signatureMissing
    case walletNotConnected

    var errorDescription: String? {
        switch self {
        case .signatureMissing:
            return "Failed to get signature from wallet"
        case .walletNotConnected:
            return "No wallet connected"
        }
    }
}
