import SwiftUI
import WebKit

struct NearConnectWebViewRepresentable: UIViewRepresentable {
    let walletManager: WalletManager
    let network: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = NearConnectWebView(walletManager: walletManager, network: network)
        return webView.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

final class NearConnectWebView: NSObject, WKUIDelegate {
    let webView: WKWebView
    private let walletManager: WalletManager
    private let network: String

    private var transactionContinuation: CheckedContinuation<[TransactionResult], Error>?

    init(walletManager: WalletManager, network: String = "mainnet") {
        self.walletManager = walletManager
        self.network = network

        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true

        // Allow inline media playback and user media access
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        // Set preferences for modern web features
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences

        let contentController = WKUserContentController()
        configuration.userContentController = contentController

        self.webView = WKWebView(frame: .zero, configuration: configuration)

        super.init()

        contentController.add(self, name: "walletBridge")
        webView.navigationDelegate = self
        webView.uiDelegate = self

        walletManager.webView = self

        loadBridgePage()
    }

    private func loadBridgePage() {
        guard let htmlPath = Bundle.main.path(forResource: "NearConnectBridge", ofType: "html"),
              let htmlContent = try? String(contentsOfFile: htmlPath, encoding: .utf8) else {
            print("Failed to load NearConnectBridge.html")
            return
        }

        webView.loadHTMLString(htmlContent, baseURL: URL(string: "https://near-treasury-app.local"))
    }

    private func initializeConnector() {
        let script = "window.initConnector('\(network)');"
        webView.evaluateJavaScript(script) { _, error in
            if let error = error {
                print("Init connector error: \(error)")
            }
        }
    }

    @MainActor
    func connect() {
        let script = "window.connect();"
        webView.evaluateJavaScript(script) { _, error in
            if let error = error {
                print("Connect error: \(error)")
                self.walletManager.handleError(message: error.localizedDescription)
            }
        }
    }

    @MainActor
    func disconnect() {
        let script = "window.disconnect();"
        webView.evaluateJavaScript(script) { _, error in
            if let error = error {
                print("Disconnect error: \(error)")
            }
        }
    }

    @MainActor
    func signAndSendTransactions(_ transactions: [WalletTransaction]) async throws -> [TransactionResult] {
        let encoder = JSONEncoder()
        let data = try encoder.encode(transactions)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw WalletError.transactionFailed("Failed to encode transactions")
        }

        let escapedJson = jsonString.replacingOccurrences(of: "'", with: "\\'")
        let script = "window.signAndSendTransactions('\(escapedJson)');"

        return try await withCheckedThrowingContinuation { continuation in
            self.transactionContinuation = continuation

            webView.evaluateJavaScript(script) { result, error in
                if let error = error {
                    self.transactionContinuation?.resume(throwing: WalletError.transactionFailed(error.localizedDescription))
                    self.transactionContinuation = nil
                } else if let resultString = result as? String {
                    do {
                        let data = resultString.data(using: .utf8) ?? Data()
                        let results = try JSONDecoder().decode([TransactionResult].self, from: data)
                        self.transactionContinuation?.resume(returning: results)
                        self.transactionContinuation = nil
                    } catch {
                        self.transactionContinuation?.resume(throwing: WalletError.transactionFailed("Failed to decode result"))
                        self.transactionContinuation = nil
                    }
                }
            }
        }
    }
}

extension NearConnectWebView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        initializeConnector()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("WebView navigation failed: \(error)")
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Allow all navigation for wallet connections
        if let url = navigationAction.request.url {
            print("Navigation to: \(url)")

            // Handle external URLs by opening in Safari
            if navigationAction.targetFrame == nil {
                // This is a popup - open in Safari
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
    }
}

extension NearConnectWebView {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // Handle popups by loading in the same WebView or opening externally
        if let url = navigationAction.request.url {
            print("Popup request to: \(url)")

            // For wallet authentication, we need to open in Safari and handle the callback
            UIApplication.shared.open(url)
        }
        return nil
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        print("JavaScript alert: \(message)")
        completionHandler()
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        print("JavaScript confirm: \(message)")
        completionHandler(true)
    }
}

extension NearConnectWebView: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.handleMessage(type: type, body: body)
        }
    }

    private func handleMessage(type: String, body: [String: Any]) {
        switch type {
        case "ready":
            walletManager.handleReady()

        case "signIn":
            if let accountsData = body["accounts"] {
                let accounts = parseAccounts(accountsData)
                walletManager.handleSignIn(accounts: accounts)
            }

        case "signOut":
            walletManager.handleSignOut()

        case "transactionSigned", "transactionsSigned":
            if let data = body["data"] {
                print("Transaction result: \(data)")
            }

        case "error":
            if let message = body["message"] as? String {
                walletManager.handleError(message: message)
                transactionContinuation?.resume(throwing: WalletError.transactionFailed(message))
                transactionContinuation = nil
            }

        default:
            print("Unknown message type: \(type)")
        }
    }

    private func parseAccounts(_ data: Any) -> [WalletAccount] {
        if let accounts = data as? [[String: Any]] {
            return accounts.compactMap { dict in
                if let accountId = dict["accountId"] as? String {
                    return WalletAccount(accountId: accountId)
                }
                return nil
            }
        } else if let accounts = data as? [String] {
            return accounts.map { WalletAccount(accountId: $0) }
        }
        return []
    }
}
