---
title: "FIN1 – Übergeordnete Projektdokumentation"
audience: ["Stakeholder", "Produkt", "Entwicklung", "Compliance"]
lastUpdated: "2026-02-01"
---

## Zweck

Dieses Dokument liefert den **Management-/Stakeholder-Überblick**: Produktvision, Ziele, Rollen, Architektur auf hoher Ebene, Tech-Stack und zentrale Richtlinien.

## 1) Produktvision und Ziele

### Kurzbeschreibung

FIN1 ist eine Investment-/Trading-Plattform, die **Investoren** mit **Tradern** verbindet. Investoren investieren in Trader-Pools; Trader handeln mit Pool-Kapital; Gewinne/Verluste werden **proportional** verteilt. Zusätzlich enthält FIN1 umfangreiche **Customer Support (CSR)**-, **Admin**- und **Compliance**-Funktionen.

### Zielgruppen

- **Investoren**: investieren in Trader, verfolgen Portfolio/Performance, erhalten Dokumente/Reports.
- **Trader**: verwalten Pool, platzieren Orders, überwachen Trades/Depot/Performance.
- **Customer Support (CSR)**: bearbeitet Tickets, Zugriff auf Kundenprofile (auditpflichtig), SLA/Analytics.
- **Admin/Compliance**: Konfiguration, Freigaben (4-Augen), Reporting, Compliance Events, Legal Docs.

### Kern-Use-Cases (High-Level)

- **Onboarding/KYC**: Mehrstufige Registrierung inkl. Risiko-/Erfahrungsabfragen.
- **Investor Journey**: Trader finden → investieren → Status/Profit/Reports verfolgen.
- **Trader Journey**: Orders platzieren → Trades ausführen → Profitverteilung → Dokumente/Invoices.
- **Wallet/Payments**: Ein-/Auszahlungen, Transaktionshistorie, Compliance bei großen Beträgen.
- **Support**: Tickets, SLA-Überwachung, Surveys, Knowledge Base/FAQ.
- **Legal**: server-driven AGB/Datenschutz/Impressum inkl. Audit Trail (Delivery + Consent).

### Business-Ziele / Erfolgskriterien (MVP-tauglich)

- **Activation**: KYC/Onboarding-Completion-Rate, Time-to-First-Investment.
- **AUM/GMV**: aktives verwaltetes Kapital (AUM), Handelsvolumen, aktive Trader/Investoren.
- **Retention**: D30/D90 Retention, wiederkehrende Sessions.
- **Trust & Compliance**: Audit-Completeness (Trade/Order/Legal), 0 ungeprüfte kritische Flows.
- **Ops-Qualität**: Uptime, RTO/RPO, Incident-Zeiten.

## 2) Stakeholder & Rollen (RACI-orientiert)

> Namen sind bewusst nicht hardcodiert; Rollen können im Projekttool/Repo ergänzt werden.

- **Product Owner (PO)**: Scope, Priorisierung, Abnahme von Requirements.
- **Tech Lead iOS**: Architektur iOS, Code-Qualität, Release iOS.
- **Tech Lead Backend**: Parse/Cloud Code, Datenmodell, Services/Infra.
- **Compliance Officer**: Pre-trade Checks, Audit Logging, Legal/AML/PSD2/GDPR Anforderungen.
- **QA Lead**: Teststrategie, Testpläne, Release-Kriterien.
- **Ops/SRE**: Deployment, Monitoring, Backups, Incident Management.
- **Customer Support Lead**: Prozesse, SLA/SLO, Eskalationen, Wissensdatenbank.

Entscheidungslogik:
- **Produktentscheidungen**: PO (mit Compliance-Freigabe bei Regulierung).
- **Technische Entscheidungen**: Tech Leads (mit PO/Compliance bei Impact).
- **Go/No-Go Release**: QA + Tech Lead + PO (+ Ops bei Backend Releases).

## 3) Architekturübersicht (High-Level)

### Systemlandschaft

```mermaid
flowchart LR
  subgraph Clients
    IOS[iOS App\nSwiftUI + MVVM + DI]
    ANDR[Android App\n(nicht im Repo)\noptional]
  end

  subgraph Edge
    NG[Nginx\n:80/:443]
  end

  subgraph Backend["Backend (Docker)"]
    PS[Parse Server\nNode.js/Express\n/parse + /dashboard + /health]
    LQ[Live Query\nWebSocket]
    MD[Market Data Service\n:8083]
    NS[Notification Service\n:8084]
    AS[Analytics Service\n:8085]
    PDF[PDF Service\n:8086]
  end

  subgraph Data
    MONGO[MongoDB\n:27018]
    REDIS[Redis\n:6380 (localhost)]
    PG[Postgres\n:5433 (localhost)]
    MINIO[MinIO\n:9002/:9003]
  end

  IOS -->|HTTPS/HTTP| NG --> PS
  IOS -->|WS| LQ
  ANDR -->|HTTPS/HTTP| NG --> PS

  PS <--> MONGO
  PS <--> REDIS
  PS --> MINIO
  PS --> PDF
  PS --> MD
  PS --> NS
  PS --> AS
  AS --> PG
```

### Zentrale Designentscheidungen (aus Code/Rules ableitbar)

- **iOS**: MVVM + Service Layer + DI via `AppServices` und `Environment(\.appServices)` (Composition Root: `FIN1/FIN1App.swift`).
- **Backend**: Parse Server als BaaS-ähnliche Basis + **Cloud Functions/Triggers** für Businesslogik (z.B. Investment-/Order-/Wallet-Workflows).
- **Compliance**: Pre-trade Checks und Audit Logging sind **Pflicht** (siehe `.cursor/rules/compliance.md`).
- **Legal**: Terms/Privacy/Imprint server-driven, auditierbar, append-only (siehe `backend/parse-server/cloud/functions/legal.js` + `triggers/legal.js`).

## 4) Technologie-Stack & Richtlinien

### iOS

- **Swift**: Swift 5.9+
- **UI**: SwiftUI (iOS 16+)
- **Architektur**: MVVM, DI, ServiceLifecycle (siehe `.cursor/rules/architecture.md`)
- **Design System**: `ResponsiveDesign` ist verpflichtend (siehe `.cursor/rules/responsive-design.md`)
- **Token Storage**: Keychain (`KeychainTokenStorage`)

### Backend

- **Node.js**: Parse Server + Express (`backend/parse-server/index.js`)
- **DB**: MongoDB (Primary), Redis (Cache), Postgres (Analytics/Reporting), MinIO (S3)
- **Legal/Audit**: Cloud Functions + Triggers

### Coding-/Projekt-Richtlinien (aus `.cursor/rules/`)

- **MVVM/DI**: Services via Protokolle, keine Singletons außerhalb Composition Root.
- **Error Handling**: zentrale `AppError`-Strategie.
- **File/Function Limits**: Funktionen ≤ 50 Zeilen, Klassen ≤ 400 Zeilen.
- **Testing**: Closure-basierte Mocks, keine `Task.sleep` in Tests.

### Branching-Strategie / CI/CD (Empfehlung)

Das Repo ist aktuell **nicht als Git-Repo initialisiert**, enthält aber `.github/workflows/` und `.githooks/`. Empfohlener Standard:

- **Branches**: `main` + kurze Feature-Branches (`feature/...`, `bugfix/...`).
- **PRs**: Template nutzen (`.github/pull_request_template.md`).
- **Qualitäts-Gates** (lokal, bevor PR/Release): `swiftformat`, `swiftlint --strict`, Build + Tests.

Nächster Schritt: in `08_PFLEGE_VERSIONING.md` ist festgelegt, wie Docs/Versionen gepflegt werden.

