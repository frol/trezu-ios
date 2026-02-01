# NEAR Treasury

A native iOS app for managing NEAR Protocol DAO treasuries. Built with SwiftUI for iOS 17+.

## Features

- **Treasury Dashboard** - Overview of assets, pending proposals, and recent activity
- **Asset Management** - View treasury holdings with real-time USD values
- **Proposal Management** - Browse, filter, and view proposal details
- **Member Directory** - View DAO members and their roles
- **Wallet Connection** - Connect via NEAR wallets (MyNearWallet, Meteor, etc.)

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Getting Started

1. Clone the repository
2. Open `NearTreasury.xcodeproj` in Xcode
3. Build and run on simulator or device

## Project Structure

```
NearTreasury/
├── App/
│   ├── NearTreasuryApp.swift    # App entry point
│   └── ContentView.swift         # Root navigation
├── Core/
│   ├── Models/                   # Data models
│   │   ├── Treasury.swift        # Treasury & config models
│   │   ├── Proposal.swift        # Proposal & voting models
│   │   ├── Asset.swift           # Asset & token models
│   │   ├── Policy.swift          # DAO policy & roles
│   │   ├── Member.swift          # Member model
│   │   └── Activity.swift        # Transaction activity
│   ├── Network/
│   │   ├── TreasuryAPIClient.swift  # API client
│   │   └── APIEndpoint.swift        # Endpoint definitions
│   └── Wallet/
│       ├── WalletManager.swift      # Wallet state management
│       └── NearConnectWebView.swift # Wallet connection UI
├── Features/
│   ├── Auth/
│   │   └── WalletConnectionView.swift
│   ├── Dashboard/
│   │   ├── DashboardView.swift
│   │   └── DashboardViewModel.swift
│   ├── Proposals/
│   │   ├── ProposalsListView.swift
│   │   ├── ProposalsListViewModel.swift
│   │   └── ProposalDetailView.swift
│   ├── Assets/
│   │   └── AssetsListView.swift
│   └── Members/
│       ├── MembersListView.swift
│       └── MembersListViewModel.swift
├── Resources/
│   ├── Assets.xcassets
│   └── NearConnectBridge.html    # Wallet connection bridge
└── Scripts/
    └── run_integration_tests.swift
```

## Architecture

The app follows MVVM architecture:

- **Models** - Codable structs matching API responses
- **ViewModels** - @Observable classes managing state and API calls
- **Views** - SwiftUI views with minimal logic

### Key Components

**TreasuryAPIClient** - Centralized API client with typed endpoints:
```swift
let assets = try await apiClient.getUserAssets(accountId: treasuryId)
let proposals = try await apiClient.getProposals(daoId: treasuryId, filters: filters)
let policy = try await apiClient.getTreasuryPolicy(treasuryId: treasuryId)
```

**WalletManager** - Manages wallet connection state:
```swift
@Observable class WalletManager {
    var isConnected: Bool
    var accountId: String?
    var selectedTreasury: Treasury?
}
```

## API

The app connects to the NEAR Treasury backend:
- Base URL: `https://near-treasury-backend.onrender.com/api`

### Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /user/treasuries?accountId=` | Get user's treasuries |
| `GET /user/assets?accountId=` | Get account assets |
| `GET /proposals/{daoId}` | Get DAO proposals |
| `GET /treasury/policy?treasuryId=` | Get DAO policy |
| `GET /treasury/config?treasuryId=` | Get treasury config |
| `GET /recent-activity?account_id=` | Get recent transactions |

## Testing

### Integration Tests

Run the standalone integration test script:

```bash
swift Scripts/run_integration_tests.swift
```

Tests against the real API using `testing-astradao.sputnik-dao.near` treasury.

### Unit Tests

Unit tests are in `NearTreasuryTests/`:
- `APIDecodingTests.swift` - Model decoding tests
- `TreasuryAPIIntegrationTests.swift` - API integration tests

To run in Xcode: Add a Unit Testing Bundle target and include the test files.

## Configuration

### Networks

The app supports:
- **Mainnet** - Production NEAR network
- **Testnet** - Test network for development

Network is configured in `WalletManager` and affects wallet connection URLs.

### Supported Wallets

- MyNearWallet
- Meteor Wallet
- HERE Wallet
- Nightly Wallet
- Manual account entry
