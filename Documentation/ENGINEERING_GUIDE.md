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

#### Offline Queue (UI responsiveness)
- `OfflineOperationQueue.processQueue()` must **not** do heavy work on the main actor. Queue state is published on `@MainActor`, but operation execution runs off-main via a dedicated actor worker (prevents “frozen UI” during app activation / reconnect).

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

#### File Size Policy (Permanent)
- Default engineering guardrail: keep Swift source files at **≤ 300 lines**.
- When a type grows, split into focused extensions/files by responsibility, e.g.:
  - `Type.swift` (core state, init, protocol conformance surface)
  - `Type+Loading.swift`
  - `Type+BackendSync.swift`
  - `Type+Computed.swift`
- Keep each new split file also ≤ 300 lines where feasible.
- Pragmatic exceptions are allowed for static data/content-heavy files (e.g. legal text constants), but must be explicitly justified in PR description.
- This policy is for maintainability/readability and does not replace SOLID/MVVM decisions; avoid "mechanical splitting" that harms cohesion.

#### PR Guardrails
- PR Template: `.github/pull_request_template.md` enforces:
  - MVVM / DI usage
  - Tests added/updated for ViewModels and navigation
  - No `.shared` outside root/previews
- Dangerfile checks (`Dangerfile.swift`):
  - Blocks nested test folders (`FIN1/FIN1Tests/`)
  - Flags `.shared` usage in non-root files
  - Warns if ViewModels changed without tests
- **Policy C — kleine PRs (Review-Phase):** Sobald wieder regelmäßig reviewed wird, größere Themen **in mehrere kleine PRs** splitten (z. B. nur Parse Cloud, nur iOS-Admin, nur CI/Workflows), statt breiter „alles in einem“-Änderungen. Ziel: schnellere Reviews, klarere Rollbacks, weniger Merge-Konflikte.

#### CI (GitHub Actions ready)
- Workflow: `.github/workflows/ci.yml` includes:
  - **Job `admin-portal`** (Ubuntu, Node 20): `npm ci` → **`npm run lint`** (ESLint 9 Flat Config) → **`npm run test:run`** (Vitest) → **`npm run build`** unter `admin-portal/`.
  - **Job `build-test-lint`** (macOS): SwiftFormat (lint mode), SwiftLint (strict), Xcode build & tests on iOS Simulator (iPhone 15 Pro), Danger on PRs.
- If using a different environment, mirror these steps in your CI to keep guardrails.

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

#### Onboarding and multi-step flows (Codable DTOs and Parse contracts)
- **Client (Swift)**: Prefer **`Codable` structs** for onboarding payloads saved to Parse (e.g. `SavedOnboardingData` in `OnboardingAPIService.swift`). Build snapshots from feature models (e.g. `SignUpData.savedOnboardingData()`). Encode to a JSON-compatible dictionary **only inside** `*APIService` when calling `ParseAPIClientProtocol.callFunction` — Views and ViewModels must not assemble raw `[String: Any]` for these flows.
- **MVVM**: Coordinators/ViewModels orchestrate; **`*APIService`** owns the network contract; no Parse types in Views (see `.cursor/rules/architecture.md`).
- **Backend (Parse Cloud Functions)**: Remains **authoritative** for validation, compliance-relevant decisions, and audit (`sanitizeObject`, `validateStepData`, `OnboardingAudit`). Client DTOs are **not** a substitute for server-side checks.
- **Contract alignment**: JSON keys produced by encoding Swift DTOs must match what `backend/parse-server/cloud/functions/user/onboarding.js` and `backend/parse-server/cloud/utils/validation.js` expect. When adding fields, update server validation if the field is required for a step.
- **Partial save vs completion**: **“Save for later”** should persist **`currentStep` + `savedData`** only; append **`completedSteps`** (and phase completion) only on successful **`completeOnboardingStep`** (or the equivalent Cloud Function), not on partial saves — keeps resume semantics clear and payloads smaller.
- **Per-step schemas (Joi)**: Implemented in [`backend/parse-server/cloud/utils/onboardingStepSchemas.js`](../backend/parse-server/cloud/utils/onboardingStepSchemas.js) (complete + partial). Optional: add JSON Schema docs under `Documentation/` for non-developer readers.
- **When changing shapes**: Add a short note to this guide or an ADR under `Documentation/` (see `.cursor/rules/documentation-checkpoints.md`). See [`Documentation/ADR-002-Onboarding-Codable-DTO.md`](ADR-002-Onboarding-Codable-DTO.md).

#### Coverage and Quality Targets
- Suggested coverage floor: 60% (ratchet +2% monthly).
- Treat warnings as errors in CI to maintain quality.

#### Parse Server, Cloud Code und Admin-Portal (FAQ / „Invalid function“)
- **Neue Cloud Functions** (`Parse.Cloud.define`) sind nur aktiv, wenn der laufende Parse-Server die **aktuelle** `cloud/`-Baumstruktur lädt. In FIN1 ist das in `docker-compose.yml` / `docker-compose.production.yml` typischerweise als **Bind-Mount** gelöst (`./backend/parse-server/cloud:/app/cloud`). Dann reicht auf dem Host: `rsync` des Ordners `backend/parse-server/cloud/` + **`docker compose … restart parse-server`** (siehe `.cursor/rules/ci-cd.md` → *FIN1-Server Deploy*). **Ohne** solches Volume (nur `COPY` im Image) muss das Image neu gebaut werden — `rsync` auf den Host allein würde dann nichts am laufenden Container ändern.
- Symptom: Aufrufe liefern **`Invalid function`** (unbekannter Function-Name). Siehe ausführlich: [`Documentation/HELP_N_INSTRUCTIONS_SERVER_DRIVEN.md`](HELP_N_INSTRUCTIONS_SERVER_DRIVEN.md) (Abschnitte *Parse Cloud Code: Deployment* und *Admin-Portal: Liste & Paging*).
- **Hilfe & Anleitung** im Admin-Portal nutzt **`getFAQs`** / **`getFAQCategories`** und **clientseitiges** Filtern + Paging, damit die Seite ohne zusätzliche Cloud-Functions zuverlässig funktioniert.
- **Backup/Restore & DEV-Wartung:** `exportFAQBackup` / `importFAQBackup` (Dry-Run + Apply) und optional **`devResetFAQsBaseline`** — letzteres nur mit **`ALLOW_FAQ_HARD_DELETE`** (in Production zusätzlich **`ALLOW_FAQ_HARD_DELETE_IN_PRODUCTION`**), siehe [`Documentation/FIN1_APP_DOCS/06_BETRIEB_PROZESSE.md`](FIN1_APP_DOCS/06_BETRIEB_PROZESSE.md) und Runbook § 8.4.
- **Teil-Sell-Kennzahlen (iOS), Finance-Smoke, System-Health, App-Ledger-Aggregation:** siehe [`Documentation/ADR-012-Partial-Sell-Metrics-Finance-Smoke-And-Ops.md`](ADR-012-Partial-Sell-Metrics-Finance-Smoke-And-Ops.md).

#### Parse Cloud: Modularisierung und Refactor-Policy (Risiko)

Vollständige, für Agenten bindende Fassung: [`.cursor/rules/parse-cloud.md`](../.cursor/rules/parse-cloud.md) (Abschnitt *Modularisierung & Refactor-Policy*). Kurzfassung für Menschen:

- **Ziel:** weniger Fehlerfläche und klarere Verantwortlichkeiten — nicht nur kürzere Dateien. Reine Zeilenzahl allein ist kein ausreichender Treiber.
- **Wann splitten:** deutlich über ~250 Zeilen *oder* mehrere fachliche Verantwortlichkeiten in einem Modul *oder* ökonomisch/regulatorisch heikle Pfade (Buchungen, Gebühren, Settlement, Reconciliation, Idempotenz).
- **Kritische Domänen:** vor oder im selben PR wie strukturelle Änderungen Tests sichern — bestehende Integration/Contract-Tests erweitern oder Characterization-/Referenzfälle ergänzen; keine stillen Verhaltensänderungen ohne Produkt-/Finance-Freigabe.
- **Schnittlinien:** Domäne vor Technik (Validierung, Domänenregeln, Posting-/Journal-Aufbau, Parse-Persistenz, Audit); **Trigger** dünn halten (registrieren + Delegation), schwere Logik in benachbarten Modulen.
- **Idempotenz:** Duplicate-Guards, `batchId`/`referenceId`-Strategien und eindeutige Annahmen nicht lockern; neue schreibende Flows explizit benennen (Retry, Doppelbuch).
- **Abnahme (Minimum):** `node --check` auf geänderte Dateien; `npx jest` unter `backend/parse-server/cloud` (oder gezielte Suites); wo möglich unveränderte Referenzausgaben für definierte Fixtures.
- **Transaktionsgrenzen, Konsistenz, Kompensation:** bei neuen oder verschobenen Grenzen **ADR/Runbook** mitziehen (ersetzt diese Policy nicht).

#### Troubleshooting
- Build errors on DI rules typically mean a ViewModel or View used a singleton directly. Inject protocols.
- If tests aren’t discovered, ensure they are under `FIN1Tests/` and target membership is `FIN1Tests`.



