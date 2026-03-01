# Trezu iOS — Architecture Reference

## Overview

Trezu is a native iOS app for multi-signature treasury management on the NEAR blockchain. It connects to NEAR DAOs (Sputnik DAO contracts), allowing members to view treasury balances, create proposals (transfer funds, add/remove members), and vote on proposals.

- **Backend API**: `https://api.trezu.app/api` (Rust/Axum, cookie-based sessions)
- **Web counterpart**: [treasury26](https://github.com/NEAR-DevHub/treasury26)
- **Wallet integration**: [near-connect-ios](https://github.com/frol/near-connect-ios) SPM package

## Build Settings

| Setting | Value |
|---------|-------|
| `SWIFT_DEFAULT_ACTOR_ISOLATION` | `MainActor` (all types implicitly `@MainActor`) |
| `IPHONEOS_DEPLOYMENT_TARGET` | `26.4` |
| `SWIFT_VERSION` | `5.0` |
| File discovery | `PBXFileSystemSynchronizedRootGroup` (auto-discovers files) |

## Project Structure

```
Trezu/Trezu/
├── TrezuApp.swift              # @main entry point, service instantiation
├── ContentView.swift           # Auth router (RootView) + treasury selector (TreasuryRootView)
├── Models/
│   ├── AnyCodable.swift        # Type-erased Codable for dynamic JSON
│   ├── Member.swift            # Member, AuthUser, AuthChallenge, UserProfile
│   ├── Proposal.swift          # Proposal, ProposalKind (12 variants), Vote, PaginatedProposals
│   ├── Token.swift             # TreasuryAsset, TokenMetadata, BalanceHistoryPoint, ActivityItem
│   └── Treasury.swift          # Treasury, TreasuryConfig, Policy, RolePermission, RoleKind, VotePolicy
├── Services/
│   ├── APIClient.swift         # Singleton HTTP client, all backend endpoints
│   ├── AuthService.swift       # @Observable auth service, NEP-413 sign-in flow
│   └── TreasuryService.swift   # @Observable treasury data + on-chain interactions
└── Views/
    ├── AcceptTermsView.swift   # Terms of service acceptance
    ├── CreateRequestView.swift # Create transfer/member proposals
    ├── DashboardView.swift     # Balance card, chart (Swift Charts), portfolio, activity
    ├── MainTabView.swift       # 4-tab container (Dashboard, Requests, Members, Settings)
    ├── MembersView.swift       # Member list by role, RoleBadge, AddMemberView
    ├── ProposalDetailView.swift# Proposal details + voting UI
    ├── ProposalsListView.swift # Filterable proposal list, status chips, pagination
    ├── SettingsView.swift      # Treasury info, policy details, account, sign out
    ├── SignInView.swift        # Sign-in screen with wallet connect button
    └── TreasuryListView.swift  # Treasury selector list
```

## Navigation Flow

```
TrezuApp
  └── RootView (auth router)
        ├── SignInView                      (unauthenticated)
        ├── AcceptTermsView                 (needs terms acceptance)
        └── TreasuryRootView                (authenticated)
              ├── TreasuryListView          (no treasury selected)
              └── MainTabView              (treasury selected)
                    ├── Tab: DashboardView
                    ├── Tab: ProposalsListView
                    │     ├── → ProposalDetailView (push)
                    │     └── → CreateRequestView  (sheet)
                    ├── Tab: MembersView
                    │     └── → AddMemberView      (sheet)
                    └── Tab: SettingsView
```

## Dependency Injection

| Object | Pattern | Injection | Reason |
|--------|---------|-----------|--------|
| `AuthService` | `@Observable` class | `.environment()` / `@Environment(AuthService.self)` | Modern Swift observation |
| `TreasuryService` | `@Observable` class | `.environment()` / `@Environment(TreasuryService.self)` | Modern Swift observation |
| `NEARWalletManager` | `ObservableObject` class | `.environmentObject()` / `@EnvironmentObject` | Third-party package uses older pattern |
| `APIClient` | Singleton (`APIClient.shared`) | Direct reference in services | Stateless HTTP client |

Created in `TrezuApp`:
```swift
@StateObject private var walletManager = NEARWalletManager()  // ObservableObject
@State private var authService = AuthService()                 // @Observable
@State private var treasuryService = TreasuryService()         // @Observable
```

## Authentication Flow (NEP-413)

1. `POST /api/auth/challenge` → backend returns `{ "nonce": "<base64-32-bytes>" }`
2. Decode Base64 nonce to `Data` (32 bytes)
3. `walletManager.connectAndSignMessage(message: "Login to Trezu", recipient: "Trezu App", nonce: nonceData)`
   - Wallet selector UI appears, user picks wallet, approves connection + signs message
   - Returns `SignInWithMessageResult` with `.account` (NEARAccount) and `.signedMessage` (JSON string)
4. Parse `signedMessage` JSON for `publicKey` (`"ed25519:..."`) and `signature` (Base64)
5. `POST /api/auth/login` with `{ accountId, publicKey, signature, message, nonce, recipient }`
   - `nonce` sent as the original Base64 string from step 1
   - Backend verifies NEP-413 payload, sets session cookie
6. Session cookie persists via `HTTPCookieStorage.shared`

**Constants**: `message = "Login to Trezu"`, `recipient = "Trezu App"` (hardcoded in `AuthChallenge` computed properties).

## JSON Conventions

The project uses **two different naming conventions** depending on the data source:

| Source | Convention | Handling |
|--------|-----------|----------|
| Backend API responses | **camelCase** (`daoId`, `isMember`, `accountId`) | Default `JSONDecoder` (no custom decoder config needed) |
| NEAR on-chain data | **snake_case** (`token_id`, `receiver_id`, `member_id`) | Explicit `CodingKeys` in model structs |

The `Treasury` model is a backend response (camelCase, no CodingKeys needed). The `Policy`, `Proposal`, and action types contain on-chain data (snake_case, use CodingKeys).

## Key Models

### Treasury (backend response, camelCase)
```
{ "daoId": "...", "config": { "name": "...", "purpose": "...", "metadata": {...} },
  "isMember": true, "isSaved": false, "isHidden": false }
```
- `name` and `purpose` are nested inside `config` (computed properties provide convenience access)

### Proposal (mixed)
- Backend wrapper fields: camelCase
- `kind` field: variant-tagged NEAR format `{ "Transfer": { "token_id": "...", "receiver_id": "...", "amount": "..." } }`
- `ProposalKind` enum has 12 variants decoded via `AnyCodable` + re-serialization

### NEAR Amounts
All token amounts are strings representing base units:
- NEAR: yoctoNEAR (10^24), e.g. `"1000000000000000000000000"` = 1 NEAR
- FT tokens: vary by `decimals` field
- Helpers: `formatNEAR(_:)`, `formatTokenAmount(_:decimals:)`, `formatCurrency(_:)`

## On-Chain Interactions

Voting and proposal creation go **directly through the wallet** to the DAO smart contract (not through the backend):

| Action | Contract Method | Gas | Deposit |
|--------|----------------|-----|---------|
| Vote | `act_proposal` | 300 TGas | 0 |
| Create proposal | `add_proposal` | 300 TGas | 0.1 NEAR (bond) |

Uses `walletManager.callFunction(contractId:methodName:args:gas:deposit:)` → returns `TransactionResult` with `.transactionHashes: [String]`.

## API Endpoints

### Auth
| Method | Path | Returns |
|--------|------|---------|
| POST | `auth/challenge` | `AuthChallenge` |
| POST | `auth/login` | `AuthUser` |
| GET | `auth/me` | `AuthUser?` |
| POST | `auth/logout` | void |
| POST | `auth/accept-terms` | void |

### Treasury
| Method | Path | Params | Returns |
|--------|------|--------|---------|
| GET | `user/treasuries` | `?accountId=` | `[Treasury]` |
| GET | `treasury/policy` | `?dao_id=` | `Policy` |
| GET | `treasury/config` | `?dao_id=` | `DaoConfig` |
| POST | `user/treasuries/save` | body: `dao_id` | void |
| POST | `user/treasuries/hide` | body: `dao_id` | void |

### Assets & Activity
| Method | Path | Params | Returns |
|--------|------|--------|---------|
| GET | `user/assets` | `?dao_id=` | `[TreasuryAsset]` |
| GET | `balance-history/chart` | `?dao_id=&interval=&limit=` | `[BalanceHistoryPoint]` |
| GET | `recent-activity` | `?dao_id=&limit=` | `[ActivityItem]` |

### Proposals
| Method | Path | Params | Returns |
|--------|------|--------|---------|
| GET | `proposals/{daoId}` | `?page=&page_size=&status=&search=` | `PaginatedProposals` |
| GET | `proposal/{daoId}/{proposalId}` | — | `Proposal` |

## UI Conventions

- **Cards**: `.regularMaterial` background + `RoundedRectangle(cornerRadius: 16)`
- **Role badges**: Purple (Governance), Blue (Financial), Orange (Requestor)
- **Status badges**: Green (approved), Red (rejected/failed), Orange (pending/inProgress), Gray (expired/removed)
- **Tab API**: Modern iOS 18+ `Tab` initializer
- **Navigation**: Value-based `.navigationDestination(for: Proposal.self)`
- **Lists**: `.insetGrouped` style throughout
- **Token icons**: `AsyncImage` with fallback letter avatar

## Data Loading

`TreasuryService.loadTreasuryData()` loads four data sources **in parallel** using `async let`:
```swift
async let policyTask = loadPolicy(daoId: daoId)
async let assetsTask = loadAssets(daoId: daoId)
async let historyTask = loadBalanceHistory(daoId: daoId)
async let activityTask = loadRecentActivity(daoId: daoId)
_ = await (policyTask, assetsTask, historyTask, activityTask)
```

Members are **derived** from the policy (not a separate API call) via `extractMembers(from:)` which collects accounts from `.group` role kinds.
