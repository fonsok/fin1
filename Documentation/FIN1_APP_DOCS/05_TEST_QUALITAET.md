---
title: "FIN1 – Test- und Qualitätsdokumentation"
audience: ["QA", "Entwicklung", "Compliance"]
lastUpdated: "2026-03-28"
---

## Zweck

Dieses Dokument definiert Teststrategie, Testarten, Kern-Szenarien und Qualitätsregeln (inkl. Monitoring/Incident Handhabung auf hoher Ebene).

## 1) Teststrategie

### Testarten

- **Unit / Component Tests (Admin-Web-Portal, React)**: **Vitest** + **React Testing Library** im Verzeichnis `admin-portal/`. Gemeinsamer **`render`** in `admin-portal/src/test/test-utils.tsx` umschließt **`MemoryRouter`** und **`ThemeProvider`**, damit Komponenten mit Routing/Theme stabil getestet werden. Ausführung: `npm run test:run` (in `admin-portal/`). In **CI** Bestandteil des GitHub-Actions-Jobs `admin-portal` (vor dem Production-Build).
- **Unit Tests (iOS)**: ViewModels/Services/Repositories, deterministisch, schnell.
- **UI Tests (iOS)**: kritische User Flows (Login/Onboarding/Invest/Order).
- **API/Contract Tests (Backend)**: Cloud Functions/Trigger-Verhalten gegen Schema/Contracts (derzeit als Empfehlung; kann später automatisiert werden).
- **E2E (System)**: iOS ↔ Backend (Docker) mit Seed-Daten (Roadmap).

### Automatisierungsgrad (Zielbild)

- Unit Tests: hoch (Pflicht für kritische Pfade)
- UI Tests: selektiv (Smoke + High-risk Flows)
- Backend: Smoke/Contract Tests, später Integration via Compose

### Coverage-Ziele (Leitplanke)

- **Kritische Pfade** (Auth, Investment, Order, Legal/Audit): ≥ 80% (realistisch, risikobasiert)
- Rest: nach Aufwand/ROI

## 2) Testfälle / Szenarien (Feature-orientiert)

> Format: **Voraussetzungen** → **Schritte** → **Erwartet**

### A) Auth/Onboarding

- **TC-A1 Signup: E-Mail Normalisierung**
  - Voraussetzungen: Backend läuft, Signup möglich
  - Schritte: registriere mit `TEST@EXAMPLE.COM`
  - Erwartet: gespeicherte Email ist lowercase; UserProfile & NotificationPreference existieren

- **TC-A2 Onboarding Step Validation**
  - Schritte: call `completeOnboardingStep` mit ungültigem `step`
  - Erwartet: Fehler `INVALID_VALUE`

### B) Investor Investments

- **TC-B1 Investment Mindestbetrag**
  - Schritte: `createInvestment` mit amount < 100
  - Erwartet: Fehler `INVALID_VALUE`

- **TC-B2 Investment Status Transition**
  - Schritte: setze Investment `active → reserved` (direkt, z.B. via Dashboard)
  - Erwartet: Trigger blockt Transition (invalid transition)

### C) Konto (Kontostand, Compliance)

- **TC-C1 Negative Balance blocken**
  - Schritte: Buchung ohne ausreichendes Guthaben
  - Erwartet: serverseitig blockiert (keine negative Balance)

- **TC-C2 Large Transaction Compliance**
  - Schritte: Ein-/Auszahlung ≥ 10k als completed
  - Erwartet: ComplianceEvent erstellt; ab 15k requiresReview=true

### D) Trading

- **TC-D1 Order Validation (limitPrice/stopPrice Pflicht)**
  - Schritte: orderType=`limit` ohne `limitPrice`
  - Erwartet: Trigger blockt

- **TC-D2 Order Executed erzeugt Trade/Invoice/Notification**
  - Schritte: setze Order status auf `executed`
  - Erwartet: Trade/Invoice/Notification erzeugt, Order verlinkt (buy flow)

### E) Legal (Audit)

- **TC-E1 TermsContent immutable**
  - Schritte: ändere `sections` einer bestehenden TermsContent Version
  - Erwartet: Trigger blockt mit `OPERATION_FORBIDDEN`

- **TC-E2 No Delete for audit classes**
  - Schritte: delete TermsContent / LegalConsent / ComplianceEvent
  - Erwartet: Trigger blockt

### F) Support/SLA

- **TC-F1 Ticket Number Generation**
  - Schritte: erstelle SupportTicket
  - Erwartet: ticketNumber folgt `TKT-YYYY-xxxxx`

- **TC-F2 SLA Targets by priority**
  - Schritte: Ticket priority=`urgent`
  - Erwartet: firstResponseTarget ~ +1h, resolutionTarget ~ +4h

### G) Admin Reports – App Ledger

- **TC-G1 Transaktionstyp-Filter wirkt auf Buchungsliste**
  - Voraussetzungen: App Ledger enthält Buchungen mit unterschiedlichen Typen
  - Schritte: `Transaktionstyp` auf z. B. `Provision` oder `Fremdkosten` setzen
  - Erwartet: In Spalte `Typ` erscheinen nur Buchungen des gewählten Typs

- **TC-G2 Zeitraum-Filter (Preset)**
  - Schritte: `Zeitraum` auf `Aktueller Monat`, danach auf `Letzter Monat` setzen
  - Erwartet: Ergebnisliste und Zähler `Buchungen (Z)` passen jeweils zum gewählten Zeitraum

- **TC-G3 Benutzerdefiniert Von/Bis**
  - Schritte: `Zeitraum = Benutzerdefiniert`, `Von`/`Bis` setzen
  - Erwartet: Nur Buchungen innerhalb des Datumsintervalls werden angezeigt

- **TC-G4 Filter + Pagination kombiniert**
  - Schritte: Filter setzen, dann Seitenumfang (`50/100/250/500`) ändern und blättern
  - Erwartet: Navigation und `Zeige X-Y von Z Buchungen` bleiben konsistent mit aktivem Filter

## 3) Teststandards (iOS, verbindlich)

Aus `.cursor/rules/testing.md`:

- **Mocks**: Closure-based Handler (kein `shouldThrowError` Pattern).
- **Async Tests**: `XCTestExpectation`, kein `Task.sleep`.
- **Repository Tests**: In-memory `UserDefaults(suiteName:)`.
- **Teststruktur**:
  - Unit: `FIN1Tests/`
  - UI: `FIN1UITests/`
  - Test Plan: `FIN1/FIN1.xctestplan`

## 4) Fehler-Handling & Monitoring (Qualitätsprozess)

### Logging-Konzept (Kurz)

- iOS: strukturierte Logs über Services (z.B. `AuditLoggingService`), keine sensitiven Daten.
- Backend: container logs + Parse logs, Health Endpoints (`/health`).

### Metriken/Alerts (Zielbild)

- Availability: Healthcheck failures
- Error rate: 5xx/4xx spikes in Cloud Functions
- Latency: p95/p99 Cloud Functions
- Compliance: Anzahl `requiresReview` Events / offene Reviews

### Umgang mit kritischen Bugs (Incident Process – Kurz)

- **Triage**: Severity bestimmen (S0/S1/S2).
- **Containment**: Feature Flag / isActive toggles / disable flows (z.B. Legal/Trading).
- **Fix**: Hotfix-Branch, Regression Tests ergänzen.
- **Postmortem**: Root Cause + Guardrail (Test/Trigger/Validator) hinzufügen.

