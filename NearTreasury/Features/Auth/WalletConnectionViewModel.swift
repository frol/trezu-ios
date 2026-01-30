import Foundation
import SwiftUI

@Observable
final class WalletConnectionViewModel {
    var isConnecting = false
    var errorMessage: String?

    func connect(walletManager: WalletManager) async {
        isConnecting = true
        errorMessage = nil

        do {
            try await walletManager.connect()
        } catch {
            errorMessage = error.localizedDescription
        }

        isConnecting = false
    }
}
