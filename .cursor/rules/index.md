---
alwaysApply: true
---

# Cursor Rules Index

This directory contains persistent rules automatically applied to Cursor AI conversations. All rules have been consolidated here from the legacy `.cursorrules` file.

## Rule Files

### Core Rules (iOS App)
- **`architecture.md`** - Main project architecture, MVVM patterns, backend integration, and coding standards
- **`compliance.md`** - Compliance and regulatory rules (MiFID II, pre-trade checks, audit logging)
- **`documentation-checkpoints.md`** - Proactive documentation checkpoints during chats
- **`testing.md`** - Testing patterns, mocking standards, and repository testing
- **`dry-constants.md`** - DRY principles and constants management
- **`trader-documents.md`** - Trader invoices & collection bill: Emittent (issuer) vs Handelsplatz (trading venue), WKN→Emittent mapping, placeholders (applies to Trader/Invoice/TradeStatement files)
- **`swiftlint.md`** - SwiftLint configuration and code quality enforcement
- **`ci-cd.md`** - Local development & code quality requirements (CI workflows are reference only); **Parse Cloud** (`configHelper/index.js`, Shadow-Guard); **FIN1-Server Deploy** nach Cloud-Code/Admin-Portal-Änderungen
- **`responsive-design.md`** - Responsive design system compliance

### Backend (Parse Cloud Code)
- **`parse-cloud.md`** - Node/Parse Cloud unter `backend/parse-server/cloud/**`: **`configHelper/index.js`**-Imports, kein Shadowing durch `configHelper.js`, Guard-Skript, Verweis Runbook § 8.2.1; **Modularisierung & Refactor-Policy** (Risiko, Tests, Domänenschnitte) (auto-applied per `filePatterns`)
- **`parse-cloud-naming.md`** - Naming-Convention-Matrix fuer Parse Cloud (`backend/parse-server/cloud/**`): Dateinamen, Cloud Function Verb-Prefixe, Verbot von Temp-/Legacy-Namen (auto-applied per `filePatterns`)

### Admin Portal (React/TypeScript)
- **`admin-portal.md`** - React/TypeScript standards for the Admin Web Portal (`admin-portal/`), inkl. **Benutzer-Detail** (`/users/:userId`, `getUserDetails`), **Listen-Sortierung** (`listSortOrder` + `applyQuerySort`), **Parse-Datumswerte** in `format.ts`, **Deploy-Pfad** (gebündelte Assets vs. `dist/` auf dem Server), **Freigaben**-Filter

### Legacy File
- **`.cursorrules`** (repository root) - **DEPRECATED**: This file is kept for backward compatibility but all rules have been migrated to `.cursor/rules/`. New rules should be added to the appropriate file in `.cursor/rules/`.

## Configuration Files Referenced

These rule files reference configuration files in the repository:
- `.swiftlint.yml` - SwiftLint rules and custom validations (used locally)
- `.github/workflows/ci.yml` - CI pipeline configuration (reference for when CI is available)
- `.github/workflows/responsive-design-compliance.yml` - Responsive design checks (reference only)

**Note**: All validation happens locally. GitHub workflow files are reference configurations for CI setup, but not required for local development.

## Quick Reference

### Architecture
- MVVM pattern with dependency injection
- Services implement protocols, not concrete types
- ViewModels created in `init()`, never in view body
- Use `NavigationStack`, not `NavigationView`
- **Class vs Struct**: ViewModels/Services/Repositories use `class` (with `final`), Models use `struct`
- **ObservableObject**: Requires `class` (ViewModels, stateful services, repositories)
- **Backend Integration**: Mock-first approach with Parse Server, protocol-based services for BaaS swapping
- **Backend Sync**: Write-through pattern (immediate) + Background batch-sync (app lifecycle hook)
- **API Services**: All backend integrations use `*APIService` pattern with `ParseAPIClientProtocol`
- See `architecture.md` for complete class vs struct decision tree and sync patterns

### Swift 6 Concurrency (Modern)
- **`@MainActor`**: Recommended for all new ViewModels (thread-safe UI updates)
- **`ResponsiveDesign` / `ComponentFactory`**: `@MainActor` (UIKit-derived metrics); see `responsive-design.md` for `TextFieldStyle` exception
- **`Sendable`**: Required for types crossing actor boundaries
- **Parse `fetchObjects` / `fetchObject`**: `T` must be **`Decodable & Sendable`** (see `architecture.md`)
- **`@unchecked Sendable` bridges**: For `await` on non-`Sendable` `any …Protocol` where `@MainActor`/protocol changes are not viable—see `architecture.md` (examples: `UncheckedDocumentServiceBridges.swift`, `UncheckedFAQAndNameChangeServiceBridges.swift`)
- **`actor`**: Preferred for shared mutable state (caches, repositories)
- **`@Observable`**: Available for iOS 17+ targets (more efficient than `ObservableObject`)
- See `architecture.md` for migration strategy and examples

### Compliance
- Pre-trade checks via `BuyOrderValidator` (extend, don't replace)
- MiFID II audit logging via `AuditLoggingService` (required for all trades)
- Risk class validation via `RiskClassCalculationService`
- Transaction limits enforced before order placement
- See `compliance.md` for complete compliance requirements

### Code Quality
- Functions ≤ 50 lines
- Swift source files target ≤ 300 lines (with justified static-content exceptions)
- Max 3 levels of nesting
- All tests in `FIN1Tests/`

### Testing Standards
- Closure-based mocking (no `shouldThrowError` pattern)
- In-memory UserDefaults for repository tests
- `XCTestExpectation` for async (never `Task.sleep`)
- See `testing.md` for complete guidelines

### UI Standards
- **MANDATORY**: Use `ResponsiveDesign` for all measurements
- No fixed fonts, spacing, padding, or corner radius
- All navigation via `NavigationStack`

### Local Development Requirements
- SwiftFormat must pass: `swiftformat FIN1 FIN1Tests FIN1UITests FIN1InvestorTests FIN1CoreRegressionTests --lint` (not `swiftformat .`)
- SwiftLint (CI): `swiftlint` — optional local gate: `swiftlint --strict`
- All tests must pass locally
- Build must succeed locally
- **No external services required** - all checks run locally

## When Working on Code

1. **Check applicable rules**: Review rule files matching your file patterns
2. **Run checks locally**: Use commands from `.cursorrules` before committing
3. **Follow patterns**: Use examples from rule files
4. **Verify locally**: All validations happen locally - no CI connection needed

## Adding Context Files

To make a config file automatically available:
1. Create a rule file in `.cursor/rules/`
2. Reference the config file and extract key requirements
3. Use frontmatter to specify when it applies (`alwaysApply` or `filePatterns`)

