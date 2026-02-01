# Agent Guidelines for NEAR Treasury

This document provides guidance for AI coding assistants working on the NEAR Treasury iOS app.

## Project Overview

- **Platform**: iOS 17+ native app
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Architecture**: MVVM with @Observable
- **API**: REST backend at `https://near-treasury-backend.onrender.com/api`

## Key Files to Know

| File | Purpose |
|------|---------|
| `Core/Models/Proposal.swift` | Proposal types with complex `ProposalKind` enum |
| `Core/Models/Policy.swift` | DAO policy and role structures |
| `Core/Network/TreasuryAPIClient.swift` | All API calls |
| `Core/Network/APIEndpoint.swift` | Endpoint URL construction |
| `Core/Wallet/WalletManager.swift` | Wallet connection state |

## Common Issues and Solutions

### API Decoding Errors

**Problem**: "the data couldn't be read because it is missing"

**Solution**: A required field is missing. Check the API response and make the field optional:
```swift
// Before
let fieldName: String

// After
let fieldName: String?
```

**Debugging**:
```bash
curl -s "https://near-treasury-backend.onrender.com/api/endpoint" | python3 -m json.tool
```

### Type Mismatches

**Problem**: "Expected Dictionary but found array"

**Solution**: The API returns a different structure than expected. Check if:
- Response is wrapped (`{"data": [...]}`) vs raw array (`[...]`)
- Response is an object vs array

### ProposalKind Decoding

The `ProposalKind` enum handles multiple formats:
- Dictionary: `{"Transfer": {...}}`
- String: `"Vote"`

Key proposal kinds:
- `Transfer` - Token transfers
- `FunctionCall` - Contract calls with `actions` array
- `AddMemberToRole` / `RemoveMemberFromRole` - Membership changes
- `ChangePolicy` - Policy updates
- `Vote` - Simple vote (string kind)

### FunctionCall Structure

FunctionCall proposals use an `actions` array:
```json
{
  "FunctionCall": {
    "receiver_id": "contract.near",
    "actions": [
      {
        "method_name": "method",
        "args": "base64...",
        "deposit": "1000000",
        "gas": "200000000000000"
      }
    ]
  }
}
```

## Testing Changes

### Quick API Check
```bash
curl -s "https://near-treasury-backend.onrender.com/api/proposals/testing-astradao.sputnik-dao.near?limit=5" | python3 -m json.tool
```

### Integration Tests
```bash
swift Scripts/run_integration_tests.swift
```

### Test Accounts
- Treasury: `testing-astradao.sputnik-dao.near`
- Members: `frol.near`, `megha19.near`

## Code Patterns

### View Model Pattern
```swift
@Observable
final class FeatureViewModel {
    enum State {
        case loading
        case loaded
        case error(Error)
    }

    private(set) var state: State = .loading
    private(set) var data: [Model] = []

    func load(apiClient: TreasuryAPIClient) async {
        state = .loading
        do {
            data = try await apiClient.getData()
            state = .loaded
        } catch {
            state = .error(error)
        }
    }
}
```

### API Client Method
```swift
func getData(param: String) async throws -> [Model] {
    try await request(.endpoint(param: param))
}
```

### Model with CodingKeys
```swift
struct Model: Codable, Identifiable, Hashable {
    let id: String
    let snakeCaseField: String

    enum CodingKeys: String, CodingKey {
        case id
        case snakeCaseField = "snake_case_field"
    }
}
```

## Do's and Don'ts

### Do
- Make new API fields optional by default
- Check API responses with curl before modifying models
- Run integration tests after API-related changes
- Use `decodeIfPresent` for optional fields
- Add debug logging when troubleshooting

### Don't
- Assume API field presence without checking
- Use force unwrapping (`!`) in production code
- Modify Package.swift for iOS-only changes (use Xcode project)
- Skip testing after model changes

## API Endpoints Reference

| Endpoint | Returns | Notes |
|----------|---------|-------|
| `/user/treasuries?accountId=` | `[Treasury]` | Array directly, 404 if none |
| `/user/assets?accountId=` | `[TreasuryAsset]` | Array directly |
| `/proposals/{daoId}` | `ProposalsResponse` | `{proposals, total}` |
| `/treasury/policy?treasuryId=` | `Policy` | Policy object directly |
| `/treasury/config?treasuryId=` | `TreasuryConfig` | Config object directly |
| `/recent-activity?account_id=` | `RecentActivityResponse` | `{data, total}` |

## Debugging Tips

1. **Add console logging** to API client for decode errors (already implemented)

2. **Check response structure** before assuming:
   ```bash
   curl -s "URL" | python3 -c "import sys,json; print(list(json.load(sys.stdin).keys()))"
   ```

3. **Compare model to response**:
   - List all expected fields in model
   - Compare against actual API response keys
   - Check for type mismatches (string vs number, array vs object)

4. **Use detailed DecodingError info**:
   ```swift
   catch let error as DecodingError {
       print("Path: \(error.codingPath)")
       print("Description: \(error.localizedDescription)")
   }
   ```

## File Organization

When adding new features:

```
Features/NewFeature/
├── NewFeatureView.swift       # Main view
├── NewFeatureViewModel.swift  # State management
└── NewFeatureDetailView.swift # Detail view (if needed)
```

Models go in `Core/Models/` if shared, or can be in the feature folder if feature-specific.
