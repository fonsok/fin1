### Engineering Guide (MVVM, Testing, CI, and Guardrails)

#### Architecture: MVVM + DI
- Views bind to ViewModels; ViewModels depend on protocols, not concrete services.
- Composition root is `FIN1/FIN1App.swift` via `AppServices` and `Environment(\.appServices)`.
- Avoid singletons (`.shared`) in non-root code. Allowed only in:
  - `FIN1App.swift` (composition root)
  - Preview fallbacks (initializer fallbacks only, never hard-coded in production paths)

#### Lifecycle and Preload
- `scenePhase == .active` starts services implementing `ServiceLifecycle` and preloads user data:
  - `NotificationService.loadNotifications(for:)`
  - `DocumentService.loadDocuments(for:)`
- `TelemetryService` tracks events (e.g., `app_active`) and can be extended for errors/metrics.

#### Testing
- Unit tests reside in `FIN1Tests/` (root only).
- UITests reside in `FIN1UITests/`.
- Xcode Test Plan: `FIN1/FIN1.xctestplan` (parallelization, timeouts, coverage enabled).
- Required tests:
  - All `*ViewModel.swift` changes should have/adjust unit tests.
  - Role-based navigation logic must be covered.
  - Lifecycle/telemetry changes should be validated if behavior changes.
- Local commands:
  - Build & test (simulator):
    - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project FIN1.xcodeproj -scheme FIN1 -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15 Pro' test`

#### Linting and Formatting
- SwiftLint config: `.swiftlint.yml` (enforces DI rules, bans `.shared` in non-root, and default singletons in VM inits).
- SwiftFormat config: `.swiftformat` (formatting rules in lint mode on CI).
- Local commands:
  - `swiftlint --strict`
  - `swiftformat . --lint`

#### PR Guardrails
- PR Template: `.github/pull_request_template.md` enforces:
  - MVVM / DI usage
  - Tests added/updated for ViewModels and navigation
  - No `.shared` outside root/previews
- Dangerfile checks (`Dangerfile.swift`):
  - Blocks nested test folders (`FIN1/FIN1Tests/`)
  - Flags `.shared` usage in non-root files
  - Warns if ViewModels changed without tests

#### CI (GitHub Actions ready)
- Workflow: `.github/workflows/ci.yml` runs on macOS:
  - SwiftFormat (lint mode)
  - SwiftLint (strict)
  - Build & tests on iOS Simulator (iPhone 15 Pro)
  - Danger checks on PRs
- If using a different platform, mirror these steps in your CI to keep guardrails.

#### How to Add a New ViewModel
- Create under `Features/<Feature>/ViewModels/`.
- `init(dependencies: any Protocols)` — do not default to singletons.
- Add corresponding unit tests in `FIN1Tests/` (constructor behavior, state changes, navigation, error cases).

#### How to Add a New Service
- Define `Protocol` (e.g., `FooServiceProtocol`) in `Features/<Feature>/Services/`.
- Provide an implementation (may expose `.shared`), but wire it only in `AppServices`.
- If needed, implement `ServiceLifecycle` to manage start/stop/reset.
- Example structure:
  ```
  Features/Dashboard/Services/
  ├── DashboardServiceProtocol.swift    # Protocol definition
  └── DashboardService.swift           # Implementation
  ```
- Register in `AppServices` and inject via environment in `FIN1App.swift`.

#### Previews
- Use environment-based services where possible; for early init use preview fallbacks (safe `.live`/`.shared` fallback inside Preview-only context).

#### Folder Structure Essentials
- App code: `FIN1/`
- Features: `FIN1/Features/<Feature>/` (Models, Services, ViewModels, Views)
- Shared: `FIN1/Shared/` (Components, Models, Services, ViewModels)
- Unit tests: `FIN1Tests/`
- UI tests: `FIN1UITests/`
- Documentation: `FIN1/Documentation/`

#### Service Architecture Pattern
- Each feature has its own service layer for business logic
- Services are protocol-based for testability
- Models are extracted from ViewModels to dedicated model files
- All services implement `ServiceLifecycle` for proper lifecycle management
- Services are registered in `AppServices` composition root

#### Coverage and Quality Targets
- Suggested coverage floor: 60% (ratchet +2% monthly).
- Treat warnings as errors in CI to maintain quality.

#### Troubleshooting
- Build errors on DI rules typically mean a ViewModel or View used a singleton directly. Inject protocols.
- If tests aren’t discovered, ensure they are under `FIN1Tests/` and target membership is `FIN1Tests`.



