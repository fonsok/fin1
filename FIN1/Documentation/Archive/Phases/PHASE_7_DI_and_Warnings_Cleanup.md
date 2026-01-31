# Phase 7: Dependency Injection & Warnings Cleanup

Date: 2025-09-05

## Scope
This phase completes the first step of Phase 7 by hardening Dependency Injection across ViewModels and reducing compiler warnings. It also modernizes a few SwiftUI APIs for iOS 16/17.

## Key Changes

### 1) Services Container and Protocol Types
- Updated `AppServices` in `FIN1App.swift` to store protocol-typed services as `any <Protocol>` to comply with modern Swift language rules.
  - userService, investmentService, notificationService, documentService, watchlistService, traderDataService.

### 2) ViewModels: Initializer Injection + any Protocols
- Converted stored properties and initializers to use `any <Protocol>`:
  - `Features/Dashboard/ViewModels/DashboardViewModel.swift`
  - `Features/Authentication/ViewModels/AuthenticationViewModel.swift`
  - `Features/Investor/ViewModels/InvestorPortfolioViewModel.swift`
  - `Features/Trader/ViewModels/TraderTradingViewModel.swift`
  - `Shared/ViewModels/WatchlistViewModel.swift`

### 3) SwiftUI API Modernization
- Replaced deprecated `onChange(of:)` signature to iOS 17-friendly variants where appropriate:
  - `Features/Dashboard/Views/DashboardView.swift`
  - `Features/Dashboard/Views/Components/DashboardTraderOverview.swift`
  - `Shared/Components/LabeledInputComponents.swift`
  - `Features/Investor/Views/Components/CreateFilterCombinationView.swift`
  - `Features/Authentication/Views/SignUp/Components/Forms/IncomeSourceOption.swift`
  - `Features/Investor/Views/Components/SearchSection.swift`
  - `Features/Authentication/Views/SignUp/Components/Steps/ContactStep.swift`

- Migrated navigation in `Features/Dashboard/Views/DashboardView.swift` from `NavigationView + NavigationLink(tag:selection:)` to `NavigationStack` with `navigationDestination(isPresented:)` for state-driven navigation.

### 4) Admin Role Consolidation
- Added `UserRole.admin` and integrated it into:
  - `MainTabView` admin tab gating (`services.userService.userRole == .admin`).
  - `TestModeService` default test users: changed “Other” test user to `.admin`.
  - Completed switch exhaustiveness in `DashboardViewModel.userRoleDisplayName` and `SignUpStep.stepsForRole(_:)`.

### 5) Deprecated Previews Suppressed
- Commented legacy previews to remove warnings:
  - `Shared/Components/ProfileView.swift` (legacy shim)
  - `Features/Authentication/Views/SignUp/Components/RiskClass/RiskClassTest.swift` (legacy shim)

### 6) Miscellaneous Cleanup
- Removed unused `mockUser` variable in `AuthenticationViewModel.performSignIn`.

## Result
- Build: Succeeds for iPhone 15 Pro simulator.
- Warnings reduced to only expected deprecation notices in legacy files or previews we intentionally keep for reference.

## How to Build
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project FIN1.xcodeproj -scheme FIN1 \
  -configuration Debug -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build
```

## Next Recommendations
- Continue migrating any remaining deprecated `NavigationLink` patterns project-wide to `NavigationStack`.
- Replace or remove any remaining legacy shims once all screens use the modular variants.
- Expand unit tests to cover Dashboard and Watchlist flows using fakes.


