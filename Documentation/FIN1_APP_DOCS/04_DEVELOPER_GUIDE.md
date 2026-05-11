---
title: "FIN1 – Developer Guide (Setup, Coding, Build/Release, How-Tos)"
audience: ["Entwicklung", "QA (technisch)", "Betrieb (technisch)"]
lastUpdated: "2026-05-11"
---

## Zweck

Dieses Dokument ist der **praktische Einstieg** für Entwickler:innen: Setup, lokale Checks, Build/Deployment, typische How-Tos.

## 1) Projekt-Setup (Getting Started)

### Voraussetzungen

- **macOS**: für iOS-Entwicklung
- **Xcode**: 15+
- **iOS Target**: iOS 16+
- **Docker**: für Backend lokal/Server
- Optional: **Homebrew** Tools (SwiftLint/SwiftFormat)

### Repo/Projekt öffnen

- Xcode Projekt: `FIN1.xcodeproj`
- iOS Code: `FIN1/`
- Backend: `backend/`

### iOS Konfiguration (Parse/PDF/Branding)

**Konfigurationsprinzip**

- `Info.plist` referenziert `$(...)` Platzhalter:
  - `FIN1ParseServerURL` → `$(FIN1_PARSE_SERVER_URL)`
  - `FIN1ParseApplicationId` → `$(FIN1_PARSE_APPLICATION_ID)`
  - `FIN1PDFServiceBaseURL` → `$(FIN1_PDF_SERVICE_BASE_URL)`
  - `CFBundleDisplayName` → `$(INFOPLIST_KEY_CFBundleDisplayName)`
- Werte kommen aus `Config/*.xcconfig`.

**Wichtige `.xcconfig` Details**

- In `.xcconfig` startet `//` einen Kommentar. URLs werden daher über `FIN1_URL_SLASH` gebaut.
- Dev-Default:
  - Simulator: `https://localhost/parse` (SSH Tunnel: `ssh -L 443:127.0.0.1:443 io@<server>`)
  - Device: `https://192.168.178.24/parse` (LAN)

### Backend lokal starten (Docker)

Es gibt mehrere Compose-Varianten. Für lokale Entwicklung ist i.d.R. `docker-compose.yml` relevant; für Server/Ubuntu `docker-compose.production.yml`.

- Environment Template:
  - Dev: `backend/env.example` → nach `backend/.env`
  - Prod: `backend/env.production.example` → nach `backend/.env` (auf Server)
- **Parse Cloud Code:** Lokal mountet `docker-compose.yml` typischerweise `./backend/parse-server/cloud` nach `/app/cloud` im `parse-server`-Container. Ohne vergleichbaren Mount auf dem Server „sieht“ ein Container nach `rsync` auf den Host **keine** neuen `Parse.Cloud.define`-Funktionen → Clients melden **`Invalid function`**. Siehe [`Documentation/HELP_N_INSTRUCTIONS_SERVER_DRIVEN.md`](../HELP_N_INSTRUCTIONS_SERVER_DRIVEN.md) (Abschnitt *Parse Cloud Code: Deployment*) und [`Documentation/FIN1_APP_DOCS/06A_BACKEND_UBUNTU_IOBOX_RUNBOOK.md`](06A_BACKEND_UBUNTU_IOBOX_RUNBOOK.md) § 8.2.

## 2) Coding-Guidelines (Kurzfassung)

Die verbindlichen Regeln stehen in `.cursor/rules/` (insb. `architecture.md`, `compliance.md`, `testing.md`, `responsive-design.md`).

- **MVVM + DI**: Services via Protokolle, keine `.shared` Singletons außerhalb Composition Root.
- **Views**: keine Businesslogik/Filter/Map/Reduce in Views.
- **Error Handling**: über `AppError`, keine direkten `error.localizedDescription` ohne Mapping.
- **ResponsiveDesign**: keine Fixed Spacing/Fonts/Padding.
- **Compliance**: Pre-trade Checks + Audit Logging sind Pflicht.

### Dokumente / Account Statement (Beleg-Links)

- **Kontoauszug → Beleg öffnen:** `AccountStatementView` / `MonthlyAccountStatementView` rufen bei Tap auf eine Zeile mit Belegreferenz zuerst den lokalen `DocumentService`-Cache (`AccountStatementEntry.referencedDocument`). Fehlt der Eintrag (z. B. Race nach Login, unvollständiger `loadDocuments`), holt `AccountStatementEntry.resolveReferencedDocument` den Datensatz per Parse-`objectId` nach (`DocumentService.resolveDocumentForDeepLink`).
- **In-flight-Dedupe:** `DocumentService.resolveDocumentForDeepLink` bündelt parallele Anfragen **pro `objectId`** zu einem Netzwerk-Fetch; `reset()` bricht ausstehende Tasks ab und leert die Map. Zentral für alle Aufrufer (Kontoauszug, Notification-Deep-Links, …).

## 3) Build & Deployment (Übersicht)

### iOS Builds/Environments

- Build Configs: `Dev`, `Staging`, `Prod` (plus `Debug/Release` je nach Setup)
- Schemes: `FIN1-Dev`, `FIN1-Staging`, `FIN1-Prod` (siehe Xcode `xcshareddata/xcschemes`)

### Lokale Quality Gates (vor PR/Release)

- `swiftformat . --lint`
- `swiftlint --strict`
- Build (Simulator)
- Tests (Simulator, Test Plan `FIN1/FIN1.xctestplan`)

Zusätzliche lokale Checks (Scripts):

- `./scripts/check-file-sizes.sh`
- `./scripts/validate-mvvm-architecture.sh`
- `./scripts/check-responsive-design.sh`

### Backend Deployment (Docker)

- Produktion/Server: `docker compose -f docker-compose.production.yml up -d`
- Health:
  - Parse Server: `/health`
  - Nginx: `/health`
  - optional Services: `:8083/health`, `:8084/health`, `:8085/health`

### Deploy: Parse Cloud + Admin-Portal (Lab/Server, Kurz)

**Operative Klarheit (zwei IPs, Env):** [`Documentation/OPERATIONAL_DEPLOY_HOSTS.md`](../OPERATIONAL_DEPLOY_HOSTS.md) — Vorlage `scripts/.env.server.example` → lokal `scripts/.env.server`. Schnellcheck:

```bash
./scripts/show-fin1-deploy-targets.sh
```

**Parse Cloud** (Shadow-Check, `rsync`, `configHelper.js`-Schutz, `parse-server`-Restart):

```bash
cd /path/to/FIN1
./scripts/deploy-parse-cloud-to-fin1-server.sh
```

Vollständige Regeln: `.cursor/rules/ci-cd.md`.

**Admin-Portal** (Build + rsync + Verifikation des JS-Bundles; Host = `FIN1_SERVER_IP` aus `scripts/.env.server`):

```bash
cd /path/to/FIN1/admin-portal
./deploy.sh
```

Architekturentscheid Teil-Sell-Kennzahlen, Finance-Smoke, System-Health: [`Documentation/ADR-012-Partial-Sell-Metrics-Finance-Smoke-And-Ops.md`](../ADR-012-Partial-Sell-Metrics-Finance-Smoke-And-Ops.md).

## 4) How-to Guides (typische Aufgaben)

### How-to: Neuen Screen hinzufügen (SwiftUI + MVVM)

- **Ordner**: im passenden Feature unter `FIN1/Features/<Feature>/Views/`
- **ViewModel**: `FIN1/Features/<Feature>/ViewModels/`
  - ViewModel wird **im `init`** der View (oder Wrapper View) als `@StateObject` erstellt, nie im body.
- **Dependencies**: über `@Environment(\.appServices)` → in ViewModel injizieren.

### How-to: Neue Parse Cloud Function anbinden

- Backend: `backend/parse-server/cloud/functions/<domain>.js` → `Parse.Cloud.define(...)`; Einbindung über die `require`-Kette ab `cloud/main.js` nicht vergessen.
- **Deploy / Sichtbarkeit:** Die Funktion existiert für Clients erst, wenn der **laufende** Parse-Server-Prozess den aktualisierten `cloud/`-Stand lädt (lokal: Container-Neustart bei Volume-Mount; Server: Volume **oder** Image-Rebuild). Symptom bei veraltetem Stand: **`Invalid function`**. Details und FAQ-Admin-Portal: [`Documentation/HELP_N_INSTRUCTIONS_SERVER_DRIVEN.md`](../HELP_N_INSTRUCTIONS_SERVER_DRIVEN.md).
- iOS: `ParseAPIClient.callFunction("<name>", parameters: ...)`
- Auth: Für user-gebundene Funktionen braucht ihr einen **gültigen `X-Parse-Session-Token`**.
  **Hinweis**: In `AppServicesBuilder` ist `sessionToken` derzeit `nil` (TODO im Code). Für produktive Calls muss der Token aus Auth/UserService in den Client injiziert werden.

### How-to: Onboarding-Payloads ändern (Swift + Node)

- **Client**: `SavedOnboardingData` (Codable) in `OnboardingAPIService.swift`; nur im `OnboardingAPIService` encodieren, nicht in Views.
- **Server**: Autoritative Prüfung in `backend/parse-server/cloud/functions/user/onboarding.js` nach `sanitizeObject`; **Joi-Schemas** in `backend/parse-server/cloud/utils/onboardingStepSchemas.js` (`validateStepData` = abgeschlossener Schritt, `validatePartialOnboardingData` = `saveOnboardingProgress`).
- **Bei neuen Pflichtfeldern/Enums**: Swift-DTO + `onboardingStepSchemas.js` + ggf. `validation.js`-Hilfsfunktionen abstimmen; siehe [`Documentation/ENGINEERING_GUIDE.md`](../ENGINEERING_GUIDE.md) und [`Documentation/ADR-002-Onboarding-Codable-DTO.md`](../ADR-002-Onboarding-Codable-DTO.md).

### How-to: Neues Feature Flag / Remote Config

- Backend: `getConfig` liefert (environment-basiert) **finanzielle Parameter aus der Klasse `Configuration`** (via `cloud/utils/configHelper`) sowie Feature Flags/Limits/Display. Source of Truth für Finanz-Config ist das Admin-Portal (4-Augen).
- iOS: `ConfigurationService` ist die zentrale Stelle für Konfiguration; er wird im `ServiceLifecycleCoordinator` mit Priorität „critical“ gestartet und ruft in `start()` `fetchRemoteDisplayConfig()` auf, um die Server-Werte (u.a. `initialAccountBalance`, `traderCommissionRate`, `appServiceChargeRate`) zu laden und lokal zu mergen. **`initialAccountBalance`**: Backend- und App-Default **0 €**; Nutzer erhalten kein automatisches Startguthaben außer was Admins in der `Configuration` hinterlegt haben (4-Augen).

**Konfigurierbare Finanzparameter:**
- `appServiceChargeRate`: App Service Charge Rate (Default: 2%, konfigurierbar über `ConfigurationService.updateAppServiceChargeRate()`)
- `traderCommissionRate`: Trader Commission Rate (Default: 10%, konfigurierbar über `ConfigurationService.updateTraderCommissionRate()`)
- Beide Rates verwenden `effective*` Properties mit Fallback auf `CalculationConstants` Defaults

### How-to: Neues Compliance-Event / Audit Trail

- iOS: `AuditLoggingService.logComplianceEvent(...)` nutzen (asynchron, non-blocking für Logging-Fehler).
- Backend: `ComplianceEvent` ist eine Parse Klasse, die auch serverseitig in Triggern erzeugt wird (z.B. large transaction).

### How-to: DEV Reset Testdaten (Trading/Investments)

Während der Entwicklungsphase kann es sinnvoll sein, alle beim Testen entstandenen Daten (Trading/Investments inkl. Belege/Buchungen) auf Knopfdruck zurückzusetzen – **ohne** Templates/Vorlagen zu verlieren.

**Admin-Portal UI:**
- Seite **System‑Status** → Bereich **Development Maintenance**
- Button: **DEV: Reset Testdaten (Trading/Investments)**
- Vor Ausführung wird ein **Preview (Dry‑Run)** mit Counts angezeigt.

**Scopes:**
- `all`: alles zurücksetzen
- `sinceHours`: nur Daten der letzten \(X\) Stunden
- `testUsers`: nur Daten von Test‑Usern (z.B. `investor1..5`, `trader1..10`, `@test.com`, `user:` Prefix). **Quelle für Namen, Passwort und Kunden‑ID‑Prefixe (ANL/TRD):** `FIN1/Shared/Constants/TestUserConstants.swift`; Backend‑Vollprofile: Cloud Function `seedTestUsers` (`backend/parse-server/cloud/functions/seed/users.js`).

**Betroffene Klassen (werden gelöscht):**
`PoolTradeParticipation`, `Commission`, `AccountStatement`, `Document`, `Invoice`, `Order`, `Holding`, `Trade`, `WalletTransaction`, `Investment`, `InvestmentBatch`, `BankContraPosting`, `AppLedgerEntry`, `Notification`, `ComplianceEvent`.

**Was bleibt erhalten:**
Templates/Vorlagen (z.B. `CSRResponseTemplate`, `CSREmailTemplate`, `CSRTemplateCategory`) sowie Legal/Config Daten.

**Serverseitige Guardrails (ENV):**
- `ALLOW_DEV_TRADING_RESET=true`
- In `NODE_ENV=production` zusätzlich: `ALLOW_DEV_TRADING_RESET_IN_PRODUCTION=true`

### How-to: Bereinigung doppelter Investment-Splits (nur DEV-Maintenance)

Falls historische Duplikate für denselben Split entstanden sind (gleicher `investorId + batchId + sequenceNumber`),
kann die Cloud Function `cleanupDuplicateInvestmentSplits` verwendet werden.

- **Dry-Run (Standard):** `dryRun=true` (oder Parameter weglassen)
- **Execute:** `dryRun=false`
- **Sicherheitsprinzip:** Es werden nur **stale `reserved`-Duplikate** entfernt, wenn für denselben Split bereits
  ein stärkerer Status (`active`/`executing`/`closed`/`completed`) existiert. Alles andere bleibt als `reviewOnly`.
- **Scan-Limit:** optional `scanLimit` (Default `1000`, Max `5000`)

### Admin-Web-Portal (`admin-portal/`, React/Vite)

- **Entwicklung:** `npm install`, `npm run dev` (siehe `admin-portal/README.md` und `FIN1_APP_DOCS/10_ADMIN_PORTAL_REQUIREMENTS.md`).
- **Qualität:** `npm run lint` (ESLint 9, `eslint.config.js`), `npm run test:run` (Vitest), `npm run build` (Typecheck via `tsc` + Vite).
- **CI:** Job `admin-portal` in `.github/workflows/ci.yml` führt dieselben Schritte auf Ubuntu aus.
- **Hilfe & Anleitung (FAQs):** Seite `FAQsPage` — **Export/Import** (`exportFAQBackup` / `importFAQBackup`, Dry‑Run wie bei AGB‑Backups) und **Development Maintenance** (`devResetFAQsBaseline`, serverseitig an `ALLOW_FAQ_HARD_DELETE` gebunden; siehe `06_BETRIEB_PROZESSE.md` und Runbook § 8.4).

