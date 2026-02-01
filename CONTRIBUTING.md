# Contributing to NEAR Treasury

## Development Setup

### Prerequisites

- macOS 14.0+ (Sonoma)
- Xcode 15.0+
- iOS 17.0+ Simulator or device

### Getting Started

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd NearTreasury
   ```

2. Open in Xcode:
   ```bash
   open NearTreasury.xcodeproj
   ```

3. Select a simulator or device and run (Cmd+R)

## Code Style

### Swift Guidelines

- Use Swift 5.9+ features
- Follow Swift API Design Guidelines
- Use `@Observable` macro for view models (iOS 17+)
- Prefer `async/await` over completion handlers

### SwiftUI Best Practices

- Keep views small and focused
- Extract reusable components
- Use `@Environment` for shared dependencies
- Avoid force unwrapping in views

### Naming Conventions

- **Views**: `*View.swift` (e.g., `DashboardView.swift`)
- **ViewModels**: `*ViewModel.swift` (e.g., `DashboardViewModel.swift`)
- **Models**: Singular noun (e.g., `Proposal.swift`, `Treasury.swift`)

## Project Structure

```
NearTreasury/
├── App/           # App entry and root navigation
├── Core/          # Shared infrastructure
│   ├── Models/    # Data models (Codable structs)
│   ├── Network/   # API client and endpoints
│   └── Wallet/    # Wallet connection logic
├── Features/      # Feature modules
│   ├── Auth/
│   ├── Dashboard/
│   ├── Proposals/
│   ├── Assets/
│   └── Members/
└── Resources/     # Assets, HTML bridges, etc.
```

### Adding a New Feature

1. Create a folder under `Features/`
2. Add view file(s): `*View.swift`
3. Add view model if needed: `*ViewModel.swift`
4. Add models to `Core/Models/` if they're shared
5. Add API endpoints to `APIEndpoint.swift`
6. Add API methods to `TreasuryAPIClient.swift`

## API Integration

### Adding a New Endpoint

1. Add the endpoint case to `APIEndpoint.swift`:
   ```swift
   case newEndpoint(param: String)

   var path: String {
       case .newEndpoint(let param):
           return "/new-endpoint/\(param)"
   }
   ```

2. Add the API method to `TreasuryAPIClient.swift`:
   ```swift
   func getNewData(param: String) async throws -> NewModel {
       try await request(.newEndpoint(param: param))
   }
   ```

3. Create/update the model in `Core/Models/`:
   ```swift
   struct NewModel: Codable {
       let field: String

       enum CodingKeys: String, CodingKey {
           case field = "api_field_name"
       }
   }
   ```

### Debugging API Issues

1. Check the Xcode console for decoding errors
2. The API client prints response previews on decode failures
3. Use `curl` to inspect raw API responses:
   ```bash
   curl -s "https://near-treasury-backend.onrender.com/api/endpoint" | python3 -m json.tool
   ```

## Testing

### Running Integration Tests

```bash
swift Scripts/run_integration_tests.swift
```

Tests run against the live API using `testing-astradao.sputnik-dao.near`.

### Adding Tests

For new API endpoints, add tests to `Scripts/run_integration_tests.swift`:

```swift
await runTest("Test name") {
    let response: ResponseType = try await fetchJSON(
        "/endpoint?param=value",
        as: ResponseType.self
    )
    try assertFalse(response.data.isEmpty, "Should have data")
}
```

### Test Treasury

Use these accounts for testing:
- **Treasury**: `testing-astradao.sputnik-dao.near`
- **Member**: `frol.near`, `megha19.near`

## Common Tasks

### Updating Models for API Changes

1. Inspect the API response:
   ```bash
   curl -s "https://near-treasury-backend.onrender.com/api/endpoint" | python3 -m json.tool
   ```

2. Update the model to match:
   - Add missing fields (make optional if not always present)
   - Update `CodingKeys` for snake_case conversion
   - Handle nested objects

3. Run integration tests to verify

### Handling Optional Fields

Always make new fields optional unless you're certain they're always present:

```swift
struct Model: Codable {
    let requiredField: String
    let optionalField: String?  // May be missing or null
}
```

### Custom Decoding

For complex types, implement custom `init(from:)`:

```swift
init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    requiredField = try container.decode(String.self, forKey: .requiredField)
    optionalField = try container.decodeIfPresent(String.self, forKey: .optionalField)
}
```

## Pull Request Process

1. Create a feature branch from `main`
2. Make your changes
3. Run integration tests
4. Build and test in Xcode
5. Submit PR with description of changes

## Questions?

Open an issue for:
- Bug reports
- Feature requests
- Questions about the codebase
