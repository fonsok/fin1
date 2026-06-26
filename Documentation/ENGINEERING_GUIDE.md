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
- **Documented test gaps (non-goals for default CI):** Full E2E against a live Parse host, manual accounting sign-off (IFRS/GOB), and full UI graph coverage are **not** implied by green `ci.yml`. When you touch ledgers, settlements, or compliance flows, extend **Jest** (`backend/parse-server`) and/or **focused `FIN1Tests`** and call out residual risk in the PR.
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
- **Policy C — kleine PRs (Review-Phase):** Sobald wieder regelmäßig reviewed wird, größere Themen **in mehrere kleine PRs** splitten (z. B. nur Parse Cloud, nur iOS-Admin, nur CI/Workflows), statt breiter „alles in einem“-Änderungen. Ziel: schnellere Reviews, klarere Rollbacks, weniger Merge-Konflikte. Die einmalige, breite CI-/Xcode-/Simulator-Stabilisierung auf `main` bleibt der **Ausnahmefall** nach dem ersten Grünwerden; im Regelbetrieb wieder kleine PRs.
- **PR vor Merge (Kurzcheckliste):**
  1. **Thema:** Ein PR = ein klar abgegrenztes Paket (Parse Cloud · iOS · CI/Workflows · admin-portal · Doku) — keine fachlich unzusammenhängenden Mix-PRs.
  2. **Qualität:** Für die berührten Bereiche die passenden Checks grün (iOS: Build/Tests wie in CI; Cloud: `npm test` unter `backend/parse-server`; Portal: `npm run lint`, `npm run test:run`, `npm run build` unter `admin-portal/`).
  3. **Beschreibung:** Zweck, Risiko/Rollback, ggf. Deploy-Hinweis (Parse-Cloud-Skript, `admin-portal/deploy.sh`), wenn Server-Artefakte betroffen sind.
  4. **Merge:** CI grün; Konflikte im Feature-Branch lösen — **kein** Force-Push / History-Rewrite auf `main`.
  5. **Git-Historie:** Bereits auf `origin/main` liegende Bündelungen **nicht** nachträglich per Squash/Rebase umschreiben. Für absichtlich als **zwei Commits** auf `main` gelassene Fixes (Bezug: `cfc62b0`, `c78a7af`): das bleibt der sinnvolle Call; Squash dort ist obsolet, sobald sie im Remote stehen — künftige Arbeit wieder in kleinen PRs führen.

#### CI (GitHub Actions ready)
- Workflow: `.github/workflows/ci.yml` includes:
  - **Job `parse-smoke-local-mock`:** among other checks, **`scripts/check-no-tracked-admin-spa-artifacts.sh`** — fails if `admin-portal/dist/` or bundle files under repo-root `admin/` are **tracked** (builds belong on the server / CI artifact only; see `.gitignore` `/admin/`).
  - **Job `admin-portal`** (Ubuntu, Node 20): `npm ci` → **`npm run lint`** (ESLint 9 Flat Config) → **`npm run test:run`** (Vitest) → **`npm run build`** unter `admin-portal/`.
  - **Job `build-test-lint`** (macOS): SwiftFormat (lint mode), SwiftLint (strict), Xcode build & tests on iOS Simulator (iPhone 15 Pro), Danger on PRs.
- If using a different environment, mirror these steps in your CI to keep guardrails.

#### Deploy — Happy-Path Lesepfad (Index)
- Ziele/Hosts/IPs: **`Documentation/OPERATIONAL_DEPLOY_HOSTS.md`**
- Pflichtablauf nach Cloud/Admin-Änderungen: **`.cursor/rules/ci-cd.md`** → Abschnitt **FIN1-Server Deploy**
- Admin-UI Build + `rsync`: **`admin-portal/deploy.sh`** (Ziel `~/fin1-server/admin/`)

#### Remote configuration (Admin / `getConfig` SSOT)

**Maßgeblich bei neuen Finanz-/Display-Parametern, Feature Flags und dem Fehlerbild „Portal zeigt X, App zeigt Y“.**

| Rolle | SSOT / Verhalten |
|--------|------------------|
| **Schreiben** | Parse-Klasse **`Configuration`** — ausschließlich **Admin Web Portal** (`requestConfigurationChange`, ggf. **`approveConfigurationChange`** / 4-Augen). Kritische Parameter: `backend/parse-server/cloud/utils/configHelper/criticalParameters.js`. |
| **Admin lesen** | Cloud Function **`getConfiguration`** → `buildDisplay()` aus `loadConfig()` — flache + `display`-Sektion für das Portal. |
| **Clients lesen (iOS)** | Cloud Function **`getConfig`** — merged **`Configuration`** (via `loadConfig`) in `financial`, `tax`, `limits`, **`display`**. Legacy-Klasse **`Config`** (environment) nur noch für ältere `features`/Limits; **Display-Flags aus dem Portal müssen explizit aus `liveConfig.display` gemerged werden** (Helfer: `cloud/functions/configuration/getConfigDisplayFlags.js`). |
| **iOS Cache** | `ConfigurationService.fetchRemoteDisplayConfig()` bei Start/Login → lokaler Cache (`AppConfiguration`/UserDefaults). **Keine Remote-Writes** aus der App (`ConfigurationError.serverManagedConfiguration`); Ausnahme: CSR-only **`updateSLAMonitoringInterval`** (lokal). |
| **Legacy blockiert** | **`updateConfig`** deprecated (`rejectDeprecatedUpdateConfig.js`) — früherer iOS-Admin-Pfad in legacy `Config.display`. |

**Checkliste — neuer Display-/Finanz-Parameter:**

1. **`parameterDefinitions.ts`** (Admin Portal) + Validierung in **`validateConfigValue.js`**
2. **`loadConfig.js`** — Feld aus `Configuration` in `display`/`financial`/`limits`/`tax` lesen
3. **`buildDisplay()`** (`functions/configuration/shared.js`) — für **`getConfiguration`**
4. **`getConfig`** in **`main.js`** — Wert aus **`liveConfig`** in Client-`display`/`financial` mergen (nicht nur legacy `Config`)
5. **iOS:** `GetConfigResponse` + `ConfigurationService.fetchRemoteDisplayConfig()` — kein `updateConfig`
6. **Doku:** [`FIN1_APP_DOCS/03_TECHNISCHE_SPEZIFIKATION.md`](FIN1_APP_DOCS/03_TECHNISCHE_SPEZIFIKATION.md), [`CONFIGURATION_4EYES_DEPLOYMENT.md`](CONFIGURATION_4EYES_DEPLOYMENT.md)

**Beispiel (2026-06):** `showCommissionBreakdownInCreditNote` — Portal „Aktiv“, App „aus“, weil `getConfig` den Merge aus `Configuration` fehlte; Fix in `getConfigDisplayFlags.js`.

**Beispiel (2026-06):** `showTraderDashboardInvestmentActiveStatus` — steuert die Depot-Kachel „Investment-Pool“ (`HoldingCard`), nicht Dashboard Quick Stats. Admin-Label: „Trader-Depot: Investment-Pool Status anzeigen“.

**iOS Admin-Tab:** `AdminDashboardView` = Read-only Diagnose (Ledger, Beleg-Suche, Drift); Role Testing nur **`#if DEBUG`**. Vollständige Konfiguration/Reports: Web-Portal.

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
- **Signup load (2026-06):** iOS coalesces partial saves (~400 ms debounce in `SignUpCoordinator+Persistence`); server upserts one `OnboardingProgress` per user, rate-limits saves, mirrors RC-5 gate on `completeOnboardingStep`. Post-deploy: run `./scripts/run-onboarding-signup-indexes-migration.sh` and optionally `LOAD_TEST_ON_SERVER=1 ./scripts/run-signup-onboarding-load-test.sh`. See [`Documentation/SCHEMA_MIGRATIONS.md`](SCHEMA_MIGRATIONS.md) and [`FIN1_APP_DOCS/02A_FEATURE_KATALOG_GUARDRAILS.md`](FIN1_APP_DOCS/02A_FEATURE_KATALOG_GUARDRAILS.md).
- **Retail role immutability (2026-06):** `_User.role` is set at Contact (`POST /users`) and must not change afterward. iOS: `WelcomeStep.isRoleSelectionLocked`, `restoreFromSavedData(lockAccountRole:)`, `applyServerRoleToSignUpData()`. Server: `assertImmutableOnboardingRole` in `saveOnboardingProgress`, `userTriggerBeforeSave` blocks investor↔trader updates. See [`FIN1_APP_DOCS/02A_FEATURE_KATALOG_GUARDRAILS.md`](FIN1_APP_DOCS/02A_FEATURE_KATALOG_GUARDRAILS.md) §3.3.
- **Onboarding shell / defer (2026-06):** `AuthenticationView` shows `MainTabView` only when `onboardingCompleted`; `AppRootContent` skips retail background sync until then; `SLAMonitoringService.canRunMonitoring` is staff-only (`admin` / `customerService`). `discoverTraders` uses `profileDisplayName.js` for safe `displayName`. Ops smoke: `./scripts/run-smoke-signup-role-immutability.sh`.
- **Per-step schemas (Joi)**: Implemented in [`backend/parse-server/cloud/utils/onboardingStepSchemas.js`](../backend/parse-server/cloud/utils/onboardingStepSchemas.js) (complete + partial). Optional: add JSON Schema docs under `Documentation/` for non-developer readers.
- **Leveraged-products knowledge test (Step 17 / backend step `risk`)**: Question catalog and version are duplicated SSOT — iOS `LeveragedProductsKnowledgeTest.swift` and `backend/parse-server/cloud/utils/leveragedProductsKnowledgeTest.js`. Server validates answer **completeness** only; RK1 assignment on failed quiz or declined total-loss acknowledgement is **client product logic** (`requiresConservativeRiskClassFromOnboarding`). Document in `Documentation/FIN1_APP_DOCS/02A_FEATURE_KATALOG_GUARDRAILS.md` and `02_REQUIREMENTS.md`.
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

#### iOS Simulator: schwarzes Fenster (iPhone 17 Pro, iOS 26)

Nach **Build Succeeded** kann der **iPhone 17 Pro**-Simulator ein zweites Fenster **„External Display“** öffnen. FIN1 rendert nur auf dem **Hauptdisplay (LCD)** — External Display bleibt **schwarz**.

**Wichtig:** **I/O → External Display → Disabled** verhindert nur *neue* External Displays. Ein **bereits offenes schwarzes Fenster** bleibt stehen — mit dem **roten Schließen-Button (✕)** schließen.

**Hauptfenster finden (Simulator aktiv, Menüleiste zeigt „Simulator“):**

1. **Fenster** (engl. **Window**) in der Menüleiste öffnen — dort stehen Einträge wie `iPhone 17 Pro` und ggf. `iPhone 17 Pro – External Display`.
2. Auf **`iPhone 17 Pro`** klicken (ohne „External Display“) → dieses Fenster nach vorne.
3. Fehlt der Eintrag: **Simulator beenden** (⌘Q), in Xcode **▶ Run** — es sollte ein **hohes** iPhone-Fenster (Dynamic Island oben) erscheinen, nicht das flache/schmale External-Display-Fenster.

**Alternativ über Xcode:** **Window → Devices and Simulators** (⇧⌘2) → links **Simulators** → **iPhone 17 Pro** wählen → Doppelklick oder Kontextmenü **Open Simulator**.

**Terminal-Reset (nur ein Simulator-Fenster):**

```bash
xcrun simctl shutdown all
xcrun simctl boot "iPhone 17 Pro"
open -a Simulator
```

Danach in Xcode erneut **▶ Run** (Destination weiterhin iPhone 17 Pro).

**Wenn das Hauptfenster (Dynamic Island, Statusleiste) ebenfalls komplett schwarz bleibt:** **Device → Erase All Content and Settings**, Simulator/Xcode neu starten.
- **Transaktionsgrenzen, Konsistenz, Kompensation:** bei neuen oder verschobenen Grenzen **ADR/Runbook** mitziehen (ersetzt diese Policy nicht).
- **Admin Portal (React/TS):** [`Documentation/ADMIN_PORTAL_NAMING_CONVENTIONS.md`](ADMIN_PORTAL_NAMING_CONVENTIONS.md) — gleiche Prinzipien wie Parse Cloud, PascalCase für Komponenten; `cloudFunction`-Namen = Parse-Verb-Matrix.
- **Beispiel `utils/accountingHelper/`:** `statements.js` ist die **Fassade** (gleiche öffentliche API; bestehende `require('…/statements')`-Imports bleiben); Implementierung in `accountStatementWriter.js` (Kontoauszugszeilen, Cash/Chain/Kompensation), `settlementGLRules.js` (`SETTLEMENT_GL_RULES`), `settlementGLPoster.js` (Settlement-Posting, Order-Fee-Breakdown). Weitere Barrel-Fassaden: `documents.js` → `documents/`, `investmentEscrow.js` → `investmentEscrow/`, `settlementCore.js` → `settlementCore/` (`settleAndDistribute`), `repair.js` → `repair/`, `traderCollectionBillBelegSnapshot.js` → `traderCollectionBillBelegSnapshot/`, `utils/investorAccountStatementMerge.js` → `investorAccountStatementMerge/`, `utils/traderAccountStatementPresentation.js` → `traderAccountStatementPresentation/`. Admin: `usersDetailStatementsAndWallet.js` → `usersDetailStatementsAndWallet/`. CF-Reads: `tradingSettlementReads.js` → `tradingSettlementReads/`. Utils: `permissions.js` → `permissions/`, `pairedTradeMirrorSync.js` → `pairedTradeMirrorSync/` (`legResolution`, `sellSync`), `poolMirrorEconomics.js` → `poolMirrorEconomics/` (`aggregatePool`, `traderSellMath`, `constants`).
- **Fassade-Policy (kurz):** Eintrittspunkt nur — **keine Logik** in der Root-Datei; Fachlogik in Submodule; öffentliche API über **`modul/publicSurface.js`** (Tier-Manifest); **Tests: `*.publicSurface.test.js` (Contract) + Submodule direkt**. Alle reorganisierten Module: `investmentEscrow`, `investorAccountStatementMerge`, `documents`, `traderCollectionBillBelegSnapshot`, `traderAccountStatementPresentation`, `repair`, `usersDetailStatementsAndWallet`, `tradingSettlementReads`, `permissions`, `pairedTradeMirrorSync`, `poolMirrorEconomics`. Swift-Analog: [`.cursor/rules/architecture.md`](../.cursor/rules/architecture.md). Regeln: [`.cursor/rules/parse-cloud.md`](../.cursor/rules/parse-cloud.md). SSOT: [`BOOKING_AND_BELEG_SSOT.md`](BOOKING_AND_BELEG_SSOT.md), [`ACCOUNT_STATEMENT_ARCHITECTURE.md`](ACCOUNT_STATEMENT_ARCHITECTURE.md), [`ADR-014`](ADR-014-Pool-Buy-Immutability-And-Snapshot-Architecture.md) (Mirror-Buy-Immutability).

#### Investment anlegen (iOS ↔ Parse, Idempotenz, Trader-IDs)

**Maßgeblich für neue Features und Debugging von „Duplicate“ / leerer Investorenliste nach Fehlern.**

| Thema | SSOT / Verhalten |
|--------|------------------|
| **Create-Sync (Investor)** | Cloud Function **`createInvestmentSplits`** (`backend/parse-server/cloud/functions/investmentCreateSplits.js`) — **ein** Round-Trip pro lokaler `batchId`, nicht mehr blindes `POST /classes/Investment` pro Split. |
| **Idempotenz-Schlüssel** | `(investorId, batchId, sequenceNumber)` — Retry nach Timeout oder App-Neustart liefert bestehende Splits (`idempotentReplay: true`), keine zweite Reservierung. Guard: `triggers/investmentDuplicateGuard.js` (`findExistingInvestmentSplit`). |
| **Investment-Nr.** | `generateInvestorInvestmentNumber` (`utils/helpers.js`) vergibt **`INV-YYYY-NNNNNNN` pro Investor und Kalenderjahr** (Sequenz startet pro `investorId` neu). |
| **Mongo-Index** | **`unique + sparse` auf `(investorId, investmentNumber)`** — nicht global nur auf `investmentNumber` (sonst E11000, wenn zwei Investoren dieselbe laufende Nummer haben). Migration: `investment_number_per_investor_compound_unique_v1` in `schemaMigrationsRegistry.js`; Init: `backend/mongodb/init/01_indexes.js`. |
| **Trader-`objectId` (iOS)** | Produktionsmodell **`InvestorTrader`** (`parseUserId` / **`backendTraderId`**) — Hydration via `discoverTraders` (`TraderDiscoveryAPIService` + `TraderCatalogMerge`). **`TraderDemoMetrics`** nur für Mock-Seed (Dashboard/Filter); Server-only-Trader ohne Demo-Overlay. **Zwei UI-Wege:** Dashboard **Top Recent Trades** = `dashboardTraders`; **Find Trader / Discover** = `traders`. Seed bleibt `mockTraders` → `InvestorTrader(mock:)`. Refresh: `refreshTraderCatalog()`. **Trader-Modul** (Buy-Order, Profit, Activation): `TraderMatchingHelper` / `TraderCatalogLookup` auf `TraderDataService`-Katalog — kein `MockTrader`-Lookup mehr. **`Investment.traderUsername`:** lokal + Parse (Migration + Backfill). Anlage: `createInvestmentSplits`. Server: `resolveTraderParseUser`. |
| **Batch-Antwort** | `createInvestmentSplits` liefert pro Split `status: created \| replayed` (+ `idempotentReplay`) und `batchStatus: committed \| replayed`. **Atomar:** scheitert ein neuer Split, werden alle in derselben Request neu angelegten Zeilen zurückgerollt (`investmentBatchAtomicRollback.js`); Fehlermeldung: `Batch-Anlage fehlgeschlagen (neue Anteile zurückgenommen)`. Pool-Cap: einmal pro Batch in der Function, `beforeSave` überspringt Per-Split-Cap wenn `investmentBatchContext` gesetzt. **Notifications (Batch):** `investmentBatchNotifications.js` — `afterSave` sammelt bei offenem Batch (`beginBatchNotificationDefer`), nach Erfolg ein Digest (Investor + Trader), bei Rollback `discardDeferredBatchNotifications`. Einzel-REST-Create unverändert pro Split. |
| **Client-Sync** | `InvestmentAPIService.saveInvestmentSplits` → `InvestmentService.syncPendingInvestmentsToBackend` (gruppiert nach `batchId`). Bei Duplicate-/Netzwerkfehler: **Reconcile** per `batchId` + `fetchInvestments`, erst dann lokaler Rollback (`InvestmentService+CreationAndStatus`). **Background:** `syncToBackend` → `refreshTraderCatalog()`, dann Sync mit `traderUsername` (`InvestmentService+TraderSyncContext`). **Fetch:** fehlendes `traderUsername` wird aus dem Trader-Katalog ergänzt (`enrichTraderUsernameFromCatalogIfNeeded`). |
| **Nach Save** | `investmentTriggerBeforeSave` (Limits, Pool-Mirror-Cap, `feeConfigSnapshot`, Nummer) + `afterSave` → `bookReserve` (GoB). Fehlgeschlagene Reserve → expliziter Orphan-Rollback (`investmentReservationRollback.js`). |

**Legacy:** `createInvestment` (einzelner Betrag, ohne Batch-Splits) und direktes REST-Create bleiben für Kompatibilität; der Investor-Investment-Sheet-Pfad nutzt den Batch-Cloud-Function-Weg.

**GoB / Buchungskontext:** [`Documentation/BOOKING_AND_BELEG_SSOT.md`](BOOKING_AND_BELEG_SSOT.md) (Abschnitt *Investment-Reservierung anlegen*).

#### Trader: Provision im Trade-Überblick (iOS, Anzeige)

| Thema | SSOT / Verhalten |
|--------|------------------|
| **Listen-Spalte „Provision“** | Keine Neuberechnung; Lesen aus `DocumentService` (Gutschrift) → `getAccountStatement(entryType: commission_credit)` via `commissionCreditTotalsByTradeId` → `InvoiceService`; Notifications + einmaliger 2 s-Fallback — [`Documentation/TRADER_COMMISSION_DISPLAY_SSOT.md`](TRADER_COMMISSION_DISPLAY_SSOT.md) |
| **Order-Cash / Stück-Caps** | Separates Thema — [`Documentation/ORDER_CASH_AMOUNT_SSOT.md`](ORDER_CASH_AMOUNT_SSOT.md) |

**API-Referenz:** [`Documentation/FIN1_APP_DOCS/03_TECHNISCHE_SPEZIFIKATION.md`](FIN1_APP_DOCS/03_TECHNISCHE_SPEZIFIKATION.md) (Cloud Functions *Investment*).

**Regression-Tests (Jest):** `backend/parse-server/cloud/functions/__tests__/investmentCreateSplits.integration.test.js` — zwei Investoren mit gleicher `INV-*`-Sequenz (compound unique), Batch-Retry (`idempotentReplay`), Duplicate-Save-Race.

#### Trader ↔ Pool-Mirror: Bid/Ask-only (Parse Cloud / Admin Report)

| Thema | SSOT / Verhalten |
|--------|------------------|
| **Verknüpfung** | Nur **Bid** (Kauf) und **Ask** je Sell-Order — keine Kopie von Trader-Einstand, `buyFeesTotal`, `totalBuyCost` auf den Pool-Leg |
| **Domain** | `backend/parse-server/cloud/utils/poolMirrorEconomics/tradeLegEconomics.js` (`tradeEconomicsSnapshot`) |
| **Persistenz** | `Trade.legEconomicsSnapshot` beim Buy/Sell/Pool-Aktivierung (Phase 3); Report liest Snapshot zuerst |
| **Pool-Stückzahl** | `computeTradeLevelPoolBuyTotalsFromBid` — max. Stück aus Reserved + Bid, nicht `floor(reserved / traderEinstand)` |
| **Contract-Monitor** | Cloud `getTraderPoolBidAskContractStatus` + Cron `run-trader-pool-bid-ask-contract-monitor.sh` |
| **Report-Performance** | Cloud `benchmarkSummaryReportTradesPage` + Cron `run-summary-report-performance-monitor.sh` (100 Zeilen, Default &lt; 8s) |
| **Statement↔GL-Monitor** | Cloud `getSettlementGLReconciliationStatus` + Cron `run-settlement-gl-reconciliation-monitor.sh`; Repair `backfillMissingSettlementGL` |

**ADR:** [`Documentation/ADR-016-Trader-Pool-Bid-Ask-Link-And-Trade-Leg-Economics.md`](ADR-016-Trader-Pool-Bid-Ask-Link-And-Trade-Leg-Economics.md), [`Documentation/ADR-014-Pool-Buy-Immutability-And-Snapshot-Architecture.md`](ADR-014-Pool-Buy-Immutability-And-Snapshot-Architecture.md)

#### Troubleshooting
- Build errors on DI rules typically mean a ViewModel or View used a singleton directly. Inject protocols.
- If tests aren’t discovered, ensure they are under `FIN1Tests/` and target membership is `FIN1Tests`.
- **Investment „Duplicate value“ / 0 Investments nach Fehler:** Prüfen ob `investmentNumber`-Index compound ist (`listSchemaMigrations`, Migration `investment_number_per_investor_compound_unique_v1`); Logs `createInvestmentSplits`; ob `MockTrader` hydratisiert (`TraderDataService: Hydrated N Parse trader IDs`).



