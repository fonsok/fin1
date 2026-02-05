---
title: "FIN1 – Developer Guide (Setup, Coding, Build/Release, How-Tos)"
audience: ["Entwicklung", "QA (technisch)", "Betrieb (technisch)"]
lastUpdated: "2026-02-01"
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
  - Simulator: `http://localhost:1338/parse` (SSH Tunnel)
  - Device: `http://192.168.178.24/parse` (LAN)

### Backend lokal starten (Docker)

Es gibt mehrere Compose-Varianten. Für lokale Entwicklung ist i.d.R. `docker-compose.yml` relevant; für Server/Ubuntu `docker-compose.production.yml`.

- Environment Template:
  - Dev: `backend/env.example` → nach `backend/.env`
  - Prod: `backend/env.production.example` → nach `backend/.env` (auf Server)

## 2) Coding-Guidelines (Kurzfassung)

Die verbindlichen Regeln stehen in `.cursor/rules/` (insb. `architecture.md`, `compliance.md`, `testing.md`, `responsive-design.md`).

- **MVVM + DI**: Services via Protokolle, keine `.shared` Singletons außerhalb Composition Root.
- **Views**: keine Businesslogik/Filter/Map/Reduce in Views.
- **Error Handling**: über `AppError`, keine direkten `error.localizedDescription` ohne Mapping.
- **ResponsiveDesign**: keine Fixed Spacing/Fonts/Padding.
- **Compliance**: Pre-trade Checks + Audit Logging sind Pflicht.

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

## 4) How-to Guides (typische Aufgaben)

### How-to: Neuen Screen hinzufügen (SwiftUI + MVVM)

- **Ordner**: im passenden Feature unter `FIN1/Features/<Feature>/Views/`
- **ViewModel**: `FIN1/Features/<Feature>/ViewModels/`
  - ViewModel wird **im `init`** der View (oder Wrapper View) als `@StateObject` erstellt, nie im body.
- **Dependencies**: über `@Environment(\.appServices)` → in ViewModel injizieren.

### How-to: Neue Parse Cloud Function anbinden

- Backend: `backend/parse-server/cloud/functions/<domain>.js` → `Parse.Cloud.define(...)`
- iOS: `ParseAPIClient.callFunction("<name>", parameters: ...)`
- Auth: Für user-gebundene Funktionen braucht ihr einen **gültigen `X-Parse-Session-Token`**.
  **Hinweis**: In `AppServicesBuilder` ist `sessionToken` derzeit `nil` (TODO im Code). Für produktive Calls muss der Token aus Auth/UserService in den Client injiziert werden.

### How-to: Neues Feature Flag / Remote Config

- Backend: `getConfig` liefert (environment-basiert) Feature Flags/Financial/Limits aus Klasse `Config` oder Defaults.
- iOS: `ConfigurationService` ist die zentrale Stelle für Konfiguration (lokal + Admin Controls).
  Empfohlen: Remote Config (Parse `Config`) als Source of Truth und iOS Cache/Fallback.

**Konfigurierbare Finanzparameter:**
- `platformServiceChargeRate`: Platform Service Charge Rate (Default: 1.5%, konfigurierbar über `ConfigurationService.updatePlatformServiceChargeRate()`)
- `traderCommissionRate`: Trader Commission Rate (Default: 5%, konfigurierbar über `ConfigurationService.updateTraderCommissionRate()`)
- Beide Rates verwenden `effective*` Properties mit Fallback auf `CalculationConstants` Defaults

### How-to: Neues Compliance-Event / Audit Trail

- iOS: `AuditLoggingService.logComplianceEvent(...)` nutzen (asynchron, non-blocking für Logging-Fehler).
- Backend: `ComplianceEvent` ist eine Parse Klasse, die auch serverseitig in Triggern erzeugt wird (z.B. large transaction).

