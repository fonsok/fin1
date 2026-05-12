# FIN1 Admin-Web-Portal: Dokumentation

> **Datum:** 2026-05-02 (Ergänzung: **System**-Seite Health/Smoke, **App Ledger** Summen/User-Filter; siehe unten „Stand 2026-05“) · zuvor 2026-04-15 (**Legal Branding / `{{APP_NAME}}`**: kanonische Pflege unter **Konfiguration → Systemparameter** (`legalAppName`, 4‑Augen); AGB & Rechtstexte nur Hinweis/Link; `updateLegalBranding` deprecated) (**vorher 2026-04-04:** Benutzer-Detailseite: Trading-/Investment-Übersicht und Kontoauszug ausführlich dokumentiert; zuvor Payload/`getUserDetails`; 2026-04-03 Freigaben: Typ-Filter, Listen-Sortierung / Parse-Datum / Deploy-Check in §5; 2026-04-01 Hilfe & Anleitung; 2026-03-28 KYB-Status CSR, Vitest/ESLint/CI, `getCompanyKyb*`)
> **Status:** MVP Implementiert ✅
> **URL:** `https://192.168.178.24/admin/`

---

## 1. Übersicht

### 1.1 Was ist das Admin Portal?

Ein web-basiertes Administrations-Portal für FIN1, das rollen-basierte Zugriffskontrolle bietet.

| Tool | Zielgruppe | Rechte |
|------|------------|--------|
| **iOS App** | `investor`, `trader` | End-User Funktionen |
| **Parse Dashboard** | `Server-Admin` | Master Key (Root) via SSH Tunnel |
| **Admin-Web-Portal** ✅ | `admin`, `business_admin`, `security_officer`, `compliance`, `customer_service` | Rollen-basiert |

### 1.2 Technologie-Stack

| Technologie | Version | Verwendung |
|-------------|---------|------------|
| React | 18+ | Frontend Framework |
| TypeScript | 5+ | Type Safety |
| Vite | 7+ | Build Tool |
| TailwindCSS | 3+ | Styling |
| TanStack Query | 5+ | Server State |
| React Router | 6+ | Routing |

### 1.3 Rollen-Übersicht

```
┌──────────────────┬─────────────────────────────────────────────┐
│ Rolle            │ Typische Position                           │
├──────────────────┼─────────────────────────────────────────────┤
│ admin            │ App Admin, CTO                              │
│ business_admin   │ CFO, Finance Manager, Accounting            │
│ security_officer │ CISO, Security Lead, DevSecOps              │
│ compliance       │ Compliance Officer, Legal, Regulatory       │
│ customer_service │ Support Agent, CSR Team                     │
└──────────────────┴─────────────────────────────────────────────┘
```

---

## 2. Implementierungsstatus

### ✅ Phase 1: MVP (Abgeschlossen)

| Feature | Status | Beschreibung |
|---------|:------:|--------------|
| Login/Logout | ✅ | E-Mail/Passwort Auth |
| Dashboard | ✅ | Statistiken, Quick Actions |
| Benutzer-Suche | ✅ | Nach Name, E-Mail, Kunden-ID, Vor-/Nachname, Benutzername, Rolle, Status (siehe `searchUsers`) |
| Benutzer-Details | ✅ | Siehe **Abschnitt „Benutzer-Detailseite“** unten (Profil, Adresse, KPIs, Kontoauszug, Aktivitäten) |
| Benutzer-Aktionen | ✅ | Suspend/Reactivate, Passwort-Reset (mit Grund/Modal; keine Selbstsperrung) |
| Ticket-Liste | ✅ | Filter nach Status, Priorität |
| 2FA-Flow | ✅ | Verification bei Login |

### Stand 2026-05: System, App Ledger, Konfiguration (Wallet)

- **System / Status & Wartung:** Seite **System** (`admin-portal/src/pages/System/`): `getSystemHealth` mit klarer Semantik bei Ladefehlern (`unknown` vs. bestätigter Ausfall), Retries nach Reboot; Karten **Settlement-Konsistenz** (`getTradeSettlementConsistencyStatus`) und **Finance Consistency Smoke** (`runFinanceConsistencySmoke`). DEV-Wartung (Reset Trading/Investments, Duplicate-Splits) ausgelagert in Subkomponenten.
- **App Ledger:** Übersichtskarten-**Summen** und **Gesamtanzahl** serverseitig aggregiert (nicht nur aktuelle Seite). **User-ID-Filter:** bei nicht-ObjectId-ähnlicher Eingabe kein striktes `equalTo(userId)`; stattdessen breitere Abfrage + serverseitiger **Fuzzy**-Match (E-Mail, Username, …). CSV enthält u. a. Business-Referenz / Gegenkonto-Hinweise je nach Backend-Version.
- **Konfiguration / Wallet:** Stufenweise **Wallet-Action-Modes** (global, Rollen, Kontotyp, nutzerbezogen + 4-Augen) ersetzen/ergänzen einfaches Ein/Aus; Admin-Portal-Konfiguration + 4-Augen-Freigaben wie in Cloud Code `wallet.js` / `fourEyes`.
- **ADR:** [`Documentation/ADR-012-Partial-Sell-Metrics-Finance-Smoke-And-Ops.md`](../ADR-012-Partial-Sell-Metrics-Finance-Smoke-And-Ops.md) (Teil-Sell-Kennzahlen iOS, Smoke-Endpoints, System-Health, Ledger-Totals).

### Benutzer-Detailseite (`/users/:userId`)

**Route:** `userId` = Parse **`objectId`** des `_User` (Link aus der Benutzerliste).

**Frontend:** `admin-portal/src/pages/Users/UserDetail.tsx` (TanStack Query `getUserDetails`), Unterkomponenten in `pages/Users/components/` (`AccountStatementCard`, `InvestmentTable`, `UserTradeCard`, `UserActionModal`, `UserShared`).

**Backend:** `getUserDetails` in `backend/parse-server/cloud/functions/admin/users.js` (Berechtigung `getUserDetails`). Aggregiert u. a.:

| Bereich | Quelle / Logik | Anzeige im Portal |
|--------|----------------|-------------------|
| Stammdaten | `_User`, `UserProfile`, primäre `UserAddress` | Karten **Benutzerdaten** und **Adresse & Status** (u. a. Kunden-ID, Anrede, Name, E-Mail, Telefon, Geburtsdatum, Rolle, Adresse, Nationalität, Account-Status, KYC-Status, Registrierung, letzter Login) |
| Kontostand (Saldo) | Parse-Klasse **`Wallet`** (falls Datensatz existiert) | Karte **Kontostand** (Saldo, Währung, letzte Aktualisierung). *Hinweis:* Produktseitig kein Crypto-Konto-Feature; es handelt sich um **Konto-/Saldoanzeige** auf Basis der gespeicherten Wallet-Entität. |
| Trader | `Trade` zu `traderId` = `user:<email>`, `PoolTradeParticipation` | Karte **Trading-Übersicht** (KPIs), Liste **Letzte Trades** mit Investoren-Zuordnung (`UserTradeCard`) |
| Investor | `Investment` zu `investorId` = `objectId` **oder** `user:<email>` | Karte **Investment-Übersicht** (KPIs inkl. reserviert/aktiv/abgeschlossen), Tabellen **Ongoing** / **Completed** (`InvestmentTable`) |
| Kontoauszug | `AccountStatement` mit `userId` = **`user:<email>`** (stableId), Anfangssaldo aus **`loadConfig`/ aktiver `Configuration`-Zeile** (`initialAccountBalance`; ohne Konfiguration **0 €**) | Karte **Cash Balance & Kontoauszug** bzw. **Account Balance & Kontoauszug** (`AccountStatementCard`): siehe Unterabschnitt **Kontoauszug** unten |
| Aktivitäten | `AuditLog` mit `resourceId` = `userId` (objectId), neueste zuerst | Karte **Letzte Aktivitäten** (sofern Einträge vorhanden) |

#### Trading- und Investment-Übersicht (rollenspezifisch)

**Gemeinsam:** Die Daten kommen aus **`getUserDetails`** (`admin/users.js`). Es werden nur **Lesewerte** angezeigt, keine Bearbeitung von Trades oder Investments im Portal.

##### Trading-Übersicht (Rolle `trader`)

- **Sichtbarkeit:** Karte erscheint, wenn `tradeSummary` gesetzt ist (Backend setzt sie nur für `role === 'trader'`).
- **KPI-Zeile** (`StatBox`): Gesamt-Trades, Abgeschlossen, Aktiv, Gesamt-Gewinn (Summe `netProfit`, sonst `grossProfit`, über abgeschlossene Trades), **Provision** (Summe der `commissionAmount` aus `PoolTradeParticipation` je abgeschlossenem Trade).
- **Liste „Letzte Trades“:** maximal **10** Einträge, neueste zuerst (`Trade`-Abfrage nach `traderId` = `user:<email>`).
- **Pro Trade** (`UserTradeCard`):
  - Kopfzeile: Trade-**#**, **Symbol**, Kurzbeschreibung, **Netto-Gewinn** (Anzeige: `netProfit`, Fallback `grossProfit`), **Status**-Badge, Anzahl Investoren (wenn Beteiligungen existieren).
  - Fußzeile: **Erstellt**, ggf. **Abgeschlossen**, **Provision** (Summe der Investor-Provisionen dieser Trade-Karte).
  - **Aufklappen** (nur wenn Investoren vorhanden): Tabelle **Beteiligte Investoren** — Name, E-Mail, **Anteil** (%; Backend liefert 0–1 oder 0–100), **Investiert**, **Gewinn-Anteil**, **Provision**, Status **Abgerechnet** / **Offen** (`isSettled`).

##### Investment-Übersicht (Rolle `investor`)

- **Sichtbarkeit:** Karte erscheint, wenn `investmentSummary` gesetzt ist (Backend nur für `role === 'investor'`).
- **KPI-Zeile:** Gesamt-Anzahl Investments, **Reserviert**, **Aktiv**, **Abgeschlossen**, Summe investierter **Beträge**, Summe **Gewinn** (aus `Investment`-Objekten; bei gesettelten Pool-Beteiligungen kann das Backend Gewinn/Status aus `PoolTradeParticipation` ableiten, falls Investment-Felder stale sind).
- **Tabellen** (`InvestmentTable`): Es werden höchstens **10** Investments geladen (neueste zuerst). Aufteilung im UI:
  - **Ongoing Investments:** Status weder `completed` noch `cancelled`
  - **Completed Investments:** Status `completed` oder `cancelled`
- **Spalten:** Investment-Nr. (gekürzte `objectId`), **Trader** (Name oder `traderId`), **Trade-Nr.** (aus verknüpftem Trade, 3-stellig), **InvestAmount**, **Profit**, **Return (%)**, **Beleg / Rechnung** (`docRef`: Referenz aus `Document`, gesucht über `AccountStatement` mit `investmentId` und `entryType` ∈ `investment_profit`, `commission_debit` und gesetztem `referenceDocumentId`), **Status**.

#### Kontoauszug (`AccountStatementCard`)

- **Sichtbarkeit:** Die Response enthält immer ein Objekt **`accountStatement`** (Summen + `entries`); die Karte wird gerendert, wenn dieses Objekt vorhanden ist.
- **Titel:** Rolle **Trader** → *„Account Balance & Kontoauszug“*; **alle anderen Rollen** (z. B. Investor) → *„Cash Balance & Kontoauszug“* (`AccountStatementCard`: `userRole === 'trader'`).
- **Datenherkunft:** Parse-Klasse **`AccountStatement`**, gefiltert mit `userId` = **`user:<email>`** (gleiche stableId wie in der App). Bis zu **100** Einträge, sortiert nach `createdAt` aufsteigend; **Anfangssaldo** wie in **`getUserDetails`**: Wert aus **`loadConfig(true).financial.initialAccountBalance`** (aktive `Configuration`-Zeile bzw. Backend-Default **0 €**). Kein separates „Magic“-Fallback mehr. Autoritative Buchungen durch Backend-Settlement: siehe `Documentation/BACKEND_CALCULATION_MIGRATION.md`.
- **Summenboxen:** **Anfangssaldo**, **Gutschriften** (Summe positiver `amount`), **Belastungen** (Summe absoluter negativer `amount`), **Nettoveränderung**, **Aktueller Saldo** (laufender Endsaldo nach den geladenen Zeilen).
- **Tabelle:** Zuerst eine Zeile **Anfangssaldo**, danach pro Eintrag: **Datum**, **Buchungstext** (`description`, optional zweite Zeile **Trade #** aus `tradeNumber`), **Typ** (Badge; deutsche Labels für u. a. `deposit`, `withdrawal`, `investment_activate`, `investment_return`, `investment_refund`, `investment_profit`, `commission_debit`, `commission_credit`, `residual_return`, `trade_buy`, `trade_sell`, `trading_fees` — unbekannte `entryType` werden **roh** angezeigt), Spalten **Belastung** / **Gutschrift** (je nach Vorzeichen von `amount`), **Saldo** (`balanceAfter`), **Beleg** (`referenceDocumentId` oder „—“).
- **Ein-/Ausklappen:** Standard **alle** Einträge sichtbar, wenn höchstens **10** Zeilen; bei mehr als **10** startet die Tabelle mit den **letzten 5** Einträgen und Link **„Alle N Einträge anzeigen“**; nach Aufklappen bei >10 Einträgen **„Weniger anzeigen“**. Keine Einträge → Hinweis *„Keine Kontoauszugseinträge vorhanden.“*

**Aktionen im Header:** Passwort zurücksetzen (`forcePasswordReset`), Sperren (`suspended`) / Reaktivieren (`active`) über `updateUserStatus` — abhängig von `usePermissions` und **keine Sperrung des eigenen Accounts**.

### ✅ Phase 2: Compliance & Finance (Abgeschlossen)

| Feature | Status | Beschreibung |
|---------|:------:|--------------|
| Compliance-Events | ✅ | Liste, Filter, Review |
| 4-Augen-Freigaben | ✅ | Approve/Reject |
| Audit-Logs | ✅ | Durchsuchbar, Filter |
| Mock-Daten | ✅ | 8 Tickets, 6 Events, 10 Logs |

### ✅ Phase 3: Security & Advanced (Abgeschlossen)

| Feature | Status | Beschreibung |
|---------|:------:|--------------|
| Finanzen-Dashboard | ✅ | Revenue, Fees, Korrekturen, Rundungsdifferenzen |
| Sicherheits-Dashboard | ✅ | Alerts, Sessions, Login-Historie |
| HTTPS | ✅ | Self-signed SSL-Zertifikat |
| 2FA Setup UI | ✅ | QR-Code, Backup-Codes, Einstellungen-Seite |

### ✅ Phase 4: Testing (Abgeschlossen)

| Feature | Status | Beschreibung |
|---------|:------:|--------------|
| Unit Tests | ✅ | Vitest, ESLint 9 (Flat Config), CI-Job `admin-portal` (`lint` → `test:run` → `build`); Stand Code: siehe `npm run test:run` / `test:coverage` |
| Component Tests | ✅ | React Testing Library |
| API Mocking | ✅ | vi.mock für Parse API |

### ✅ Phase 5: Polish (Teilweise abgeschlossen)

| Feature | Status | Beschreibung |
|---------|:------:|--------------|
| E-Mail-Benachrichtigungen | ✅ | Brevo SMTP, Templates, Cloud Functions |
| Echte Backend-Daten | ⏳ | Cloud Functions erweitern |
| E2E Tests | ⏳ | Playwright für kritische Flows |

---

## 3. Projektstruktur

```
admin-portal/
├── src/
│   ├── api/
│   │   ├── parse.ts          # Parse REST API (direkt, kein SDK)
│   │   └── admin.ts          # Cloud Function Wrapper
│   ├── components/
│   │   ├── ui/               # Button, Card, Input, Badge
│   │   ├── Layout.tsx        # Sidebar + Header
│   │   └── TwoFactorVerify.tsx
│   ├── context/
│   │   └── AuthContext.tsx   # Auth State Management
│   ├── hooks/
│   │   └── usePermissions.ts # Permission-basierte Navigation
│   ├── i18n/
│   │   └── de.ts             # Deutsche Übersetzungen
│   ├── pages/
│   │   ├── Login.tsx
│   │   ├── Dashboard.tsx
│   │   ├── Users/            # UserList, UserDetail, components/ (AccountStatement, Investments, Trades, Modal)
│   │   ├── Tickets/          # TicketList
│   │   ├── Compliance/       # ComplianceEvents
│   │   ├── Approvals/        # ApprovalsList
│   │   ├── Audit/            # AuditLogs
│   │   ├── Templates/        # Response Templates
│   │   ├── KYBReview/        # Company KYB Prüfung (Review, Detail, Decision, Reset)
│   │   └── CSR/              # CSR Web Panel (siehe Abschnitt 10)
│   │       ├── pages/        # CreateTicket, TicketDetails, etc.
│   │       ├── components/   # TemplateDropdown, CustomerSelection, etc.
│   │       ├── templates.ts  # Default-Textbausteine
│   │       └── api.ts        # CSR-spezifische API
│   ├── utils/
│   │   └── format.ts         # Date, Currency, Status Formatter
│   ├── App.tsx               # Routes
│   ├── test/
│   │   ├── setup.ts          # Vitest (+ localStorage-Mocks)
│   │   └── test-utils.tsx    # render mit MemoryRouter + ThemeProvider
│   └── main.tsx              # Entry Point
├── eslint.config.js          # ESLint 9 Flat Config
├── vitest.config.ts
├── vite.config.ts
├── tailwind.config.js
└── package.json
```

---

## 4. API-Integration

### 4.1 Architektur

Das Admin Portal verwendet **direkte REST API Calls** zum Parse Server (kein Parse SDK wegen Vite-Kompatibilität).

```typescript
// src/api/parse.ts
async function cloudFunction<T>(name: string, params?: Record<string, unknown>): Promise<T> {
  const response = await fetch(`/parse/functions/${name}`, {
    method: 'POST',
    headers: {
      'X-Parse-Application-Id': 'fin1-app-id',
      'X-Parse-Session-Token': sessionToken,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(params || {}),
  });
  const result = await response.json();
  return result.result;
}
```

### 4.2 Verwendete Cloud Functions

| Function | Bereich | Beschreibung |
|----------|---------|--------------|
| `searchUsers` | Users | Benutzersuche |
| `getUserDetails` | Users | Aggregierte Benutzerdetails (Profil, Adresse, optional Wallet, rollenabhängig Trades/Investments, **Kontoauszug** aus `AccountStatement`, Audit-Schnipsel); siehe Abschnitt **Benutzer-Detailseite** |
| `updateUserStatus` | Users | Status ändern |
| `forcePasswordReset` | Users | Passwort zurücksetzen |
| `getAdminDashboard` | Dashboard | Statistiken |
| `getTickets` | Tickets | Ticket-Liste |
| `getComplianceEvents` | Compliance | Events-Liste |
| `reviewComplianceEvent` | Compliance | Event prüfen |
| `getPendingApprovals` | Approvals | Ausstehende Freigaben, eigene Anträge, Historie, alle Anträge |
| `approveRequest` | Approvals | Genehmigen |
| `rejectRequest` | Approvals | Ablehnen |
| `withdrawRequest` | Approvals | Eigenen pending Antrag zurückziehen (nur Antragsteller) |
| `getAuditLogs` | Audit | Log-Liste |
| `getFAQCategories` | FAQs | FAQ-Kategorien für Landing/Help Center/CSR; im Bereich **Hilfe & Anleitung** ohne `location`-Parameter, damit alle aktiven Kategorien für Dropdowns geladen werden |
| `getFAQs` | FAQs | Server‑getriebene FAQs für Landing/Help Center/CSR; **Hilfe & Anleitung** ruft mit `context: 'admin'` auf (siehe `admin-portal/src/pages/FAQs/api.ts`). Liste: bis zu **500** Einträge vom Server, **Filter und Paging** der Tabelle **im Browser** (`FAQsPage.tsx`). Hintergrund und „Invalid function“ bei neuen Functions: [`../HELP_N_INSTRUCTIONS_SERVER_DRIVEN.md`](../HELP_N_INSTRUCTIONS_SERVER_DRIVEN.md) |
| `createFAQ` | FAQs | Admin‑funktion, neue FAQ anlegen (inkl. Multi‑Kontext/Multi‑Kategorie) |
| `updateFAQ` | FAQs | Admin‑funktion, bestehende FAQ aktualisieren |
| `deleteFAQ` | FAQs | Admin‑funktion, FAQ archivieren (Soft Delete) |
| `createFAQCategory` | FAQs | Admin‑funktion, neue FAQ‑Kategorie anlegen (Slug + Flags) |
| `exportFAQBackup` | FAQs | JSON‑Backup aller FAQ‑Kategorien und ‑Einträge (Admin, `manageTemplates`) |
| `importFAQBackup` | FAQs | JSON‑Restore mit **Dry‑Run** und Apply: Kategorien per **`slug`** anlegen/aktualisieren, FAQs per **`faqId`** anlegen/aktualisieren; Warnungen bei nicht auflösbaren Kategorie‑Referenzen (`manageTemplates`) |
| `devResetFAQsBaseline` | FAQs / **DEV** | Destruktive Baseline‑Pflege (nur mit **`ALLOW_FAQ_HARD_DELETE=true`**, in Production zusätzlich **`ALLOW_FAQ_HARD_DELETE_IN_PRODUCTION=true`**): Sicherheits‑JSON, Klonen aktiver (`isPublished`, nicht archiviert) FAQs, Hard‑Delete alter aktiver Zeilen und aller inaktiven FAQs. Siehe `06A_BACKEND_UBUNTU_IOBOX_RUNBOOK.md` § 8.4 |
| `migrateFAQEnglishFields` | FAQs / Ops | Einmal‑Migration: Legacy `questionDe`/`answerDe` → kanonisch `questionEn`/`answerEn`; Admin‑Session mit `manageTemplates` oder Aufruf mit **Master Key** vom Server (Runbook: `06A_BACKEND_UBUNTU_IOBOX_RUNBOOK.md` § 8.3). Parameter `dryRun: true` simuliert ohne Schreiben |
| `listTermsContent` | AGB & Rechtstexte | Rechtstext-Versionen listen (Filter: documentType, language) |
| `getTermsContent` | AGB & Rechtstexte | Eine Version inkl. Abschnitte zum Klonen/Bearbeiten |
| `createTermsContent` | AGB & Rechtstexte | Neue Version anlegen (terms/privacy/imprint, append-only) |
| `setActiveTermsContent` | AGB & Rechtstexte | Version für documentType+Sprache als aktiv setzen |
| `getDefaultLegalSnippetSections` | AGB & Rechtstexte | Standard-Snippet-Abschnitte (DE/EN) für neue Version (z. B. „Snippet-Abschnitte einfügen“) |
| `getDefaultLegalSnippetSectionsPublic` | Backend/Skripte | Wie oben, ohne Auth; für Seed-Skript `scripts/seed-legal-snippets.js` |
| `getCompanyKybSubmissions` | KYB-Status | Firmen-KYB-Einreichungen nach Status filtern |
| `getCompanyKybSubmissionDetail` | KYB-Status | Detail-Ansicht inkl. Audit-Trail für eine Einreichung |
| `reviewCompanyKyb` | KYB-Status | Genehmigen, Ablehnen oder Nachbesserung anfordern (nicht CSR) |
| `resetCompanyKyb` | KYB-Status | Abgelehnte/Nachbesserung-Einreichung auf Entwurf zurücksetzen (nicht CSR) |

**Rollen (Backend, `permissions/constants.js`):** `business_admin` und `compliance` besitzen die vollen KYB-Functions einschließlich `reviewCompanyKyb` / `resetCompanyKyb`. Die Rolle `customer_service` hat **`getCompanyKybSubmissions`** und **`getCompanyKybSubmissionDetail`** (Lesen für Support), nicht jedoch Entscheiden oder Zurücksetzen.

**Hinweis Navigation (Admin-UI):** FAQ unter **„Hilfe & Anleitung“**; Rechtstexte unter **„AGB & Rechtstexte“**; Firmen-KYB unter **„KYB-Status“** (`/kyb-review`, Icon building-office).

**Seite Approvals (`/approvals`)** – vier Tabs:
- **Freigaben erteilen**: Pending Anträge anderer Admins (Genehmigen/Ablehnen)
- **Eigene Anträge**: Vom aktuellen User eingereichte, noch offene Anträge (mit Zurückziehen)
- **Alle Anträge**: Chronologische Liste aller Anträge aller Admins (neueste zuerst); bei eigenen pending Anträgen Button „Zurückziehen“
- **Abgeschlossen**: Genehmigte/abgelehnte/zurückgezogene Anträge (letzte 30 Tage)
- **Typ filtern** (oberhalb der Liste): Dropdown **Antragsart** (z. B. Konfigurationsänderung gesamt, Korrekturbuchung, …) und **Konfigurationsparameter** (dynamisch aus `metadata.parameterName` der geladenen Anträge, z. B. App-Servicegebühr, Startguthaben, Trader-Provision). Filterung **clientseitig** auf den jeweils aktiven Tab; Tab-Badge-Zahlen entsprechen der gefilterten Menge.

**Sidebar „Freigaben“**: Solange offene Anträge existieren (Anträge zur Freigabe oder eigene pending Anträge), wird am Navigationspunkt „Freigaben“ ein rotes Badge mit der Anzahl angezeigt (Polling alle 30 s). Beide Admins sehen das Badge, bis alle Anträge bearbeitet sind.

---

## 5. Deployment

### 5.1 Aktuelle Konfiguration

- **Server:** Ubuntu 24.04 (192.168.178.24)
- **Pfad:** `/home/io/fin1-server/admin/`
- **URL:** `https://192.168.178.24/admin/`
- **Nginx:** Location `/admin` mit SPA-Routing

### 5.2 Build & Deploy

```bash
# Auf Mac (Development)
cd admin-portal
npm run build

# Empfohlen: Build + Rsync gemäß deploy.sh
npm run deploy

# Alternativ manuell auf Server kopieren (Ziel muss dem Nginx-alias entsprechen)
scp -r dist/* io@192.168.178.24:~/fin1-server/admin/
```

**Wichtig:** Der Browser lädt die statischen Dateien aus dem Verzeichnis, das Nginx unter `/admin` ausliefert (z. B. `~/fin1-server/admin/` → `/var/www/admin`). Ein veraltetes `admin-portal/dist/` **allein** auf dem Server ist irrelevant, wenn nicht nach `admin/` synchronisiert wurde. Nach Deploy prüfen: in `index.html` referenziertes `index-*.js` muss mit dem Bundle auf dem Server übereinstimmen (z. B. `curl …/admin/ | grep index-`).

### 5.3 Nginx-Konfiguration

```nginx
location /admin {
    alias /var/www/admin;
    try_files $uri $uri/ @admin_fallback;
}

location @admin_fallback {
    root /var/www;
    rewrite ^ /admin/index.html break;
}
```

### 5.4 Listen-Sortierung & Parse-Datumswerte (technisch)

- **Sortierung:** Cloud-Function-Aufrufe laufen über `admin-portal/src/api/parse.ts` → `cloudFunction()`. Bei Listen mit `sortBy`/`sortOrder` sendet der Client zusätzlich **`listSortOrder`** (gleicher Wert wie normalisiertes `sortOrder`), weil Parse Server Body und Query-String zusammenführt und Query-Parameter den Body überschreiben können. Backend: `backend/parse-server/cloud/utils/applyQuerySort.js` (`resolveListSortOrder`, Whitelist `allowed` pro Function).
- **Datumsanzeige:** Parse REST liefert Daten oft als `{ "__type": "Date", "iso": "…" }`. Formatierung über `formatDate` / `formatDateTime` in `admin-portal/src/utils/format.ts` (unterstützt diese Objekte).

---

## 6. Sicherheit

### 6.1 Authentifizierung

- Login via Parse `/login` Endpoint
- Session Token in `localStorage`
- Automatische Session-Validierung bei App-Start
- Logout löscht alle lokalen Daten

### 6.2 Autorisierung

- Jede Cloud Function prüft `requireAdminRole()`
- Permissions werden via `getMyPermissions` geladen
- Navigation wird rollen-basiert angezeigt
- 4-Augen-Prinzip verhindert Selbst-Genehmigung

### 6.3 Geplant: HTTPS

- Let's Encrypt Zertifikate
- Automatische Erneuerung via Certbot

---

## 7. Entwicklung

### 7.1 Lokale Entwicklung

```bash
cd admin-portal
npm install
npm run dev
# Öffne http://localhost:3000
```

### 7.2 Vite Proxy

```typescript
// vite.config.ts
proxy: {
  '/parse': {
    target: 'https://192.168.178.24',
    changeOrigin: true,
  },
}
```

### 7.3 Cursor Rules

Siehe `.cursor/rules/admin-portal.md` für:
- TypeScript Standards
- React Component Patterns
- TailwindCSS Guidelines
- API Layer Patterns

### 7.4 Lint (ESLint 9)

```bash
cd admin-portal
npm run lint
```

Konfiguration: `eslint.config.js` (Flat Config: `@eslint/js`, `typescript-eslint`, `eslint-plugin-react-hooks`, `eslint-plugin-react-refresh`). In CI Teil des Jobs **admin-portal** in `.github/workflows/ci.yml`.

---

## 8. Testing

### 8.1 Test-Setup

```bash
# Tests ausführen
npm run test:run

# Mit Watch-Modus
npm run test

# Coverage-Report
npm run test:coverage
```

### 8.2 Test-Statistiken

| Metrik | Wert |
|--------|------|
| Test Files | 12 |
| Tests | 191 (Stand 2026-03; `npm run test:run`) |
| Coverage | `npm run test:coverage` (Ziele variieren nach Modulen) |

### 8.3 Test-Kategorien

| Kategorie | Tests | Dateien |
|-----------|:-----:|---------|
| UI Components | 45 | Badge, Button, Card, Input |
| Pages | 28 | Login, Dashboard |
| Auth | 34 | AuthContext, TwoFactorVerify |
| API | 18 | parse.ts |
| Utilities | 49 | format.ts |
| Hooks | 11 | usePermissions |

**Hinweis:** Gemeinsamer `render` in `src/test/test-utils.tsx` kapselt `MemoryRouter` und `ThemeProvider`, damit Komponenten mit `useTheme()` / `Link` zuverlässig testbar sind.

---

## 9. E-Mail-Benachrichtigungen

### 9.1 Konfiguration

E-Mail-Benachrichtigungen werden über **Brevo (ehemals Sendinblue)** SMTP versendet.

**Backend-Konfiguration** (`docker-compose.yml`):
```yaml
environment:
  - SMTP_HOST=smtp-relay.brevo.com
  - SMTP_PORT=587
  - SMTP_USER=a16f37001@smtp-brevo.com
  - SMTP_PASS=<smpt-key>
  - SMTP_FROM=noreply@fin1.de
  - SMTP_SECURE=false
  - SUPPORT_EMAIL=a16f37001@smtp-brevo.com
```

### 9.2 Verfügbare E-Mail-Funktionen

| Funktion | Cloud Function | Beschreibung |
|----------|----------------|--------------|
| **Tickets** | Automatisch via Trigger | Neue Tickets, Updates, Antworten |
| **4-Augen-Freigaben** | Automatisch via Trigger | Benachrichtigung an Approver |
| **Security Alerts** | `sendSecurityAlertEmail` | Kritische Sicherheitswarnungen |
| **Passwort-Reset** | `sendPasswordResetEmail` | Reset-Link per E-Mail |
| **Test-E-Mail** | `sendTestEmail` | SMTP-Konfiguration testen |

### 9.3 E-Mail-Templates

Templates befinden sich in `backend/parse-server/cloud/utils/emailService.js`:
- **HTML + Plain Text** - Alle E-Mails haben beide Formate
- **Branding** - FIN1-Farben und -Styling
- **Deutsche Sprache** - Alle Texte auf Deutsch

### 9.4 Cloud Functions

E-Mail-bezogene Cloud Functions in `backend/parse-server/cloud/functions/notifications.js`:
- `testEmailConfig` - Testet SMTP-Konfiguration
- `sendTestEmail` - Sendet Test-E-Mail an beliebige Adresse
- `sendPasswordResetEmail` - Passwort-Reset E-Mail
- `sendSecurityAlertEmail` - Security-Warnung senden

---

## 10. CSR Web Panel (Standalone)

### 10.1 Übersicht

Das CSR Web Panel ist ein eigenständiges Portal für Kundenservice-Mitarbeiter (`customer_service` Rolle).

| Merkmal | Beschreibung |
|---------|--------------|
| **URL** | `https://192.168.178.24/admin/csr/` |
| **Login** | Separater Login unter `/admin/csr/login` |
| **Rolle** | Nur `customer_service` Rolle erlaubt |

### 10.2 Features

| Feature | Status | Beschreibung |
|---------|:------:|--------------|
| Dashboard | ✅ | Ticket-Statistiken, Quick Actions |
| Ticket-Liste | ✅ | Filter nach Status, Priorität, Agent |
| Ticket-Details | ✅ | Vollständige Ticket-Ansicht, Antworten |
| Ticket erstellen | ✅ | Mit Kundenauswahl und Textbausteinen |
| Kunden-Suche | ✅ | Nach Name, E-Mail, ID |
| Kunden-Details | ✅ | Profil, KYC-Status, Tickets |
| Analytics | ✅ | Performance-Metriken |
| Templates | ✅ | Textbausteine verwalten |
| FAQs | ✅ | FAQ-Verwaltung (Sidebar: „Hilfe & Anleitung“): Multi‑Kontext/Multi‑Kategorie, neue Kategorien, **Export/Import (Backup/Restore)** mit Vorschau, **Development Maintenance** (DEV‑Baseline, gated per ENV) |
| AGB & Rechtstexte | ✅ | Terms, Datenschutz, Impressum versioniert verwalten (Filter, neue Version, Klonen, Als aktiv setzen) |
| KYC-Status | ✅ | Übersicht KYC pro Kunde (`/csr/kyc`) |
| KYB-Status | ✅ | Übersicht eingereichte Firmen-KYB (`/csr/kyb`); gleiche Oberfläche wie Admin **KYB-Status**, aber ohne Prüfen/Zurücksetzen sofern die Session kein `reviewCompanyKyb` / `resetCompanyKyb` hat |

#### 10.2.1 FAQ-Verwaltung – Details

- **Multi‑Kontext:** Eine FAQ kann gleichzeitig mehreren Kontexten zugeordnet werden, z.B. `Help Center`, `Landing Page`, `Investor`, `Trader` sowie zukünftigen, frei definierbaren Kontext‑Tags.
- **Multi‑Kategorie:** Eine FAQ kann mehreren FAQ‑Kategorien (`categoryIds`) zugeordnet werden; im UI werden alle Kategorien angezeigt und im Filter berücksichtigt.
- **Legacy‑Kompatibilität:** Das Backend hält die Felder `categoryId` (Primär‑Kategorie) und `source` (Primär‑Kontext) automatisch mit den Arrays (`categoryIds`, `contexts`) synchron, sodass bestehende Clients (Swift‑App, ältere Scripts) weiterhin funktionieren.
- **Neue Kategorien:** Im FAQ‑Editor können neue Kategorien direkt erzeugt werden. Diese werden serverseitig als `FAQCategory` mit `slug`, `title`, `displayName`, `icon`, `sortOrder`, `isActive`, `showOnLanding`, `showInHelpCenter`, `showInCSR` angelegt.
- **Export (Backup) / Import (Restore):** Vollbackup wie `exportFAQBackup` (JSON). Import ruft `importFAQBackup` mit **Dry‑Run‑Vorschau** und anschließendem bestätigten Lauf auf (analog AGB & Rechtstexte). Tooltips im UI beschreiben Umfang und Ablauf.
- **Development Maintenance (FAQ):** Gelbe Karte oben auf der Seite „Hilfe & Anleitung“ — DEV‑Baseline‑Reset (`devResetFAQsBaseline`): nur sinnvoll auf nicht‑produktiven Umgebungen oder mit bewusst gesetzten ENV‑Flags (siehe Betriebsdokumentation / Runbook). **Hard‑Deletes** von `FAQ`/`FAQCategory` sind serverseitig an **`ALLOW_FAQ_HARD_DELETE`** gebunden; Production zusätzlich **`ALLOW_FAQ_HARD_DELETE_IN_PRODUCTION`**.

#### 10.2.2 AGB & Rechtstexte – Details

- **Dokumenttypen:** AGB/Terms of Service, Datenschutz (Privacy Policy), Impressum. Jeder Typ wird mit Sprache (DE/EN) und Versionierung geführt.
- **Filter:** Nach Dokumenttyp (Alle / AGB / Datenschutz / Impressum) und Sprache. Die Statistik-Karte „Dokumenttyp“ zeigt das lesbare Label (z. B. „Datenschutz“).
- **Workflow:** Neue Version (leer), oder aus bestehender Version klonen → Abschnitte bearbeiten → speichern (append-only) → „Als aktiv setzen“. Bestehende Versionen werden nicht editiert (Immutability).
- **Leerzustand:** Typ-spezifische Meldung (z. B. „Keine Datenschutz-Versionen gefunden“) mit Hinweis auf neue Version oder Klonen. Details: `Documentation/LEGAL_DOCS_AUDIT_TRAIL.md`.
- **Schritt-für-Schritt (Abschnitt ändern):** Siehe `Documentation/AGB_RECHTSTEXTE_ADMIN_ANLEITUNG.md`.
- **Versionsanzeige:** Pro Version werden „Gültig ab“ und „Aktualisiert“ mit **Datum und Uhrzeit** (TT.MM.JJ, HH:MM) angezeigt, damit der Stand der Version eindeutig erkennbar ist.
- **Bearbeiten-Button:** In der aufgeklappten Abschnittsliste hat jeder Abschnitt einen Button **„Bearbeiten“**. Ein Klick klont die Version und öffnet den Editor mit vorausgefüllter Suche auf diesen Abschnitt (Titel/ID), sodass der gewünschte Abschnitt sofort sichtbar ist.
- **Suchfunktion im Editor:** Beim Anlegen einer neuen Version (Klonen) kann im Editor nach Abschnitten gesucht werden (Titel, Inhalt, ID); die Abschnittsliste wird gefiltert, ohne die Reihenfolge oder Daten zu ändern.
- **Änderungen zur Vorgängerversion:** Beim Aufklappen einer Version erscheint der Bereich „Änderungen zur Vorgängerversion“. Über **„Änderungen anzeigen“** wird die unmittelbar vorherige Version geladen und ein Vergleich angezeigt (hinzugefügte, entfernte, geänderte Abschnitte) – ohne manuelles Durchsuchen der Vorgängerversion.
- **Development Maintenance:** Gelbe Karte — `devResetLegalDocumentsBaseline` (Dry‑Run, dann bestätigter Lauf). Hard‑Deletes nur mit **`ALLOW_LEGAL_HARD_DELETE`** (+ in Production **`ALLOW_LEGAL_HARD_DELETE_IN_PRODUCTION`**). Hover‑Texte der Export/Import‑Buttons erläutern Umfang und Ablauf.
- **Legal Branding (`{{APP_NAME}}`)**: kein direktes Editieren mehr auf dieser Seite; stattdessen Deep‑Link zu **Konfiguration** (`/configuration`) und Pflege als **`legalAppName`** (4‑Augen). Serverseitig ist `updateLegalBranding` deprecated/blockiert.
- **Import-Button-Policy (Best Practice):**
  - **`Import (Restore)`** nur für vollständige Backups (globaler Restore mit Archivierung/Deaktivierung bestehender Versionen).
  - **`Import active (as new)`** für Release/Migration einzelner Dokumentgruppen (z. B. nur Terms DE+EN als neue Versionen).
- **Limit-Warnungen im UI:** Bei Export/Restore/Active-Import werden serverseitige `warnings` im Dialog angezeigt (z. B. wenn ein Server-Limit erreicht wurde).
- **Namens-Sache:** Rechtstexte sollen `{{APP_NAME}}` verwenden; die Anzeige wird aus `legalAppName` hydratisiert. Feste Literale wie `bbb` sind als Altbestand zu behandeln und per neuer Version zu bereinigen.

### 10.3 Textbausteine (Ticket-Erstellung)

Bei der Ticket-Erstellung stehen vordefinierte Textbausteine zur Verfügung:

**Betreff-Vorlagen (20 Stück):**
| Kategorie | Beispiele |
|-----------|-----------|
| 👤 Konto | Kontosperrung aufheben, Passwort zurücksetzen, Anmeldeproblem |
| 📋 KYC | Dokumente nachfordern, Verifizierung abgelehnt, Adressnachweis |
| 🔧 Technisch | App-Fehler, App-Update, Verbindungsproblem |
| 💰 Finanzen | Rückerstattung, Transaktion prüfen, Gebühren erklären |
| 📄 Allgemein | Allgemeine Anfrage, Feedback, Beschwerde |

**Beschreibungs-Vorlagen (14 Stück):**
| Kategorie | Beispiele |
|-----------|-----------|
| 👋 Begrüßung | Standard-Begrüßung, Formelle Begrüßung |
| 👤 Konto | Konto entsperrt, Passwort-Reset Anleitung |
| 📋 KYC | Dokumente anfordern, KYC erfolgreich |
| 🔧 Technisch | App-Update, Cache leeren, Neuinstallation |
| 💰 Finanzen | Rückerstattung eingeleitet, Transaktion wird geprüft |
| 🏁 Abschluss | Standard-Abschluss, Problem gelöst, Weiteres Vorgehen |

### 10.4 Backend-Integration

Templates werden aus der MongoDB-Collection `CSRResponseTemplate` geladen:

```javascript
// Cloud Function
Parse.Cloud.define('getResponseTemplates', async (request) => {
  requireAdminRole(request);
  const { role, category, language = 'de' } = request.params;
  // ... returns templates filtered by role
});
```

**Fallback**: Falls die API nicht verfügbar ist, werden Default-Templates aus dem Frontend verwendet.

### 10.5 Komponenten-Struktur

```
admin-portal/src/pages/CSR/
├── pages/
│   ├── CreateTicket.tsx       # 362 Zeilen (refactored)
│   └── ...
├── components/
│   ├── TemplateDropdown.tsx   # Wiederverwendbare Template-Auswahl
│   ├── CustomerSelection.tsx  # Kundenauswahl-Komponenten
│   └── CustomerInfoSidebar.tsx # Kunden-Info Sidebar
├── templates.ts               # Default-Textbausteine
├── types.ts                   # TypeScript-Interfaces
└── api.ts                     # CSR API-Funktionen
```

### 10.6 CSR-Rollen und Berechtigungen (RBAC)

Die CSR-Berechtigungen folgen dem **Least Privilege Principle** und sind in der iOS-App unter `CustomerSupportPermission.swift` und `CustomerSupportPermissionSet.swift` definiert.

#### 10.6.1 Level 1 Support (L1)

| Kategorie | Berechtigung |
|-----------|--------------|
| **👁️ Ansicht** | Kundenprofil anzeigen |
| | KYC-Status anzeigen |
| | Investments anzeigen |
| | Dokumente anzeigen |
| | Benachrichtigungen anzeigen |
| | Support-Verlauf anzeigen |
| **✏️ Bearbeitung** | Kontaktdaten aktualisieren |
| **💬 Support** | Support-Ticket erstellen |
| | Support-Ticket beantworten |
| | Interne Notiz hinzufügen |

> ⚠️ **Banking Best Practice:** L1 hat bewusst **keinen** Zugriff auf Trades (Preise, Volumen, Strategien). Trade-Anfragen müssen an L2 eskaliert werden.

#### 10.6.2 Level 2 Support (L2)

*Enthält alle L1-Berechtigungen plus:*

| Kategorie | Berechtigung |
|-----------|--------------|
| **👁️ Ansicht** | Trades anzeigen |
| **✏️ Bearbeitung** | Adresse aktualisieren *(4-Augen)* |
| | Name aktualisieren *(4-Augen)* |
| | Passwort zurücksetzen |
| | Konto entsperren |
| **💬 Support** | An Admin eskalieren |
| **📋 Compliance** | KYC-Prüfung einleiten |

#### 10.6.3 Fraud Analyst

*Enthält alle L1-Berechtigungen plus:*

| Kategorie | Berechtigung |
|-----------|--------------|
| **🔍 Betrugsbekämpfung** | Fraud-Alerts anzeigen |
| | Transaktionsmuster anzeigen |
| | Verdächtige Aktivität melden |
| | Konto temporär sperren (<24h) |
| | Konto erweitert sperren (>24h) *(4-Augen)* |
| | Zahlungskarte sperren |
| | Chargeback einleiten *(4-Augen)* |
| **📋 Compliance** | AML-Flags anzeigen |
| **💬 Support** | An Admin eskalieren |

#### 10.6.4 Compliance Officer

*Enthält alle L1-Berechtigungen plus:*

| Kategorie | Berechtigung |
|-----------|--------------|
| **👁️ Ansicht** | Trades anzeigen *(für AML/SAR)* |
| | Audit-Protokolle anzeigen |
| **📋 Compliance** | Compliance-Prüfung anfordern |
| | KYC-Prüfung einleiten |
| | KYC-Entscheidung genehmigen *(4-Augen)* |
| | AML-Flags anzeigen |
| | SAR-Meldungen anzeigen |
| | SAR-Meldung erstellen *(4-Augen)* |
| | DSGVO-Anfrage bearbeiten |
| | DSGVO-Löschung genehmigen *(4-Augen)* |
| **🔐 Genehmigung** | SAR-Einreichung genehmigen |
| | Kontosperrung genehmigen |

#### 10.6.5 Tech Support

*Enthält alle L1-Berechtigungen plus:*

| Kategorie | Berechtigung |
|-----------|--------------|
| **📋 Compliance** | Audit-Protokolle anzeigen |
| **💬 Support** | An Admin eskalieren |

> ℹ️ Tech Support hat **keinen Schreibzugriff** auf Kundendaten – Fokus liegt auf technischer Analyse.

#### 10.6.6 Teamlead

*Enthält alle L2-Berechtigungen plus:*

| Kategorie | Berechtigung |
|-----------|--------------|
| **🔍 Betrugsbekämpfung** | Fraud-Alerts anzeigen |
| | Transaktionsmuster anzeigen |
| **📋 Compliance** | AML-Flags anzeigen |
| | Audit-Protokolle anzeigen |
| | SAR-Meldungen anzeigen |
| | Compliance-Prüfung anfordern |
| **🔐 Genehmigung** | Kontosperrung genehmigen |
| | Chargeback genehmigen |
| | SAR-Einreichung genehmigen |
| | KYC-Entscheidung genehmigen |
| | DSGVO-Löschung genehmigen |
| **⚙️ Administration** | Agenten-Berechtigungen verwalten |

#### 10.6.7 4-Augen-Prinzip

Folgende Aktionen erfordern eine Genehmigung durch **Teamlead** oder **Compliance Officer**:

| Aktion | Genehmiger |
|--------|------------|
| Adresse aktualisieren | Teamlead, Compliance |
| Name aktualisieren | Teamlead, Compliance |
| Konto erweitert sperren (>24h) | Teamlead, Compliance |
| Chargeback einleiten | Teamlead |
| SAR-Meldung erstellen | Compliance |
| DSGVO-Löschung | Teamlead, Compliance |

> ⚠️ **Wichtig:** Requester ≠ Approver (Backend-enforced)

#### 10.6.8 Berechtigungs-Kategorien

| Icon | Kategorie | Beschreibung |
|:----:|-----------|--------------|
| 👁️ | Ansicht | Nur-Lesen-Zugriff auf Kundendaten |
| ✏️ | Bearbeitung | Schreibzugriff (teilweise mit Genehmigung) |
| 💬 | Support | Ticket-Operationen |
| 📋 | Compliance | KYC/AML/GDPR-Operationen |
| 🔍 | Betrugsbekämpfung | Fraud-Detection und Kontosperrungen |
| 🔐 | Genehmigung | 4-Augen-Approver-Rechte |
| ⚙️ | Administration | Team-Management |

**Source of Truth (Code):**
- iOS: `FIN1/Features/CustomerSupport/Models/CustomerSupportPermission.swift`
- iOS: `FIN1/Features/CustomerSupport/Models/CustomerSupportPermissionSet.swift`
- iOS: `FIN1/Features/CustomerSupport/Models/CSRRole.swift`
- Backend: `backend/parse-server/cloud/functions/seed.js` (seedCSRPermissions)
- Backend: `backend/parse-server/cloud/functions/support.js` (Cloud Functions)

### 10.6.9 Backend-Integration (MongoDB)

Die CSR-Berechtigungen sind auch im Backend (MongoDB) verfügbar:

**Collections:**
| Collection | Beschreibung |
|------------|--------------|
| `CSRPermission` | Einzelne Berechtigungen mit Metadaten |
| `CSRRole` | Rollen mit Berechtigungs-Sets |

**Seeding:**
```bash
# Via Admin Portal oder curl:
curl -k -X POST "https://192.168.178.24/parse/functions/seedCSRPermissions" \
  -H "X-Parse-Application-Id: FIN1_APP_2024" \
  -H "X-Parse-Session-Token: <session-token>" \
  -H "Content-Type: application/json"

# Force Reseed (löscht existierende zuerst):
curl -k -X POST "https://192.168.178.24/parse/functions/forceReseedCSRPermissions" ...
```

**Cloud Functions:**
| Function | Beschreibung |
|----------|--------------|
| `getCSRPermissions` | Alle Berechtigungen (gruppiert nach Kategorie) |
| `getCSRRoles` | Alle Rollen mit Berechtigungen |
| `getCSRRolePermissions` | Berechtigungen einer spezifischen Rolle |
| `checkCSRPermission` | Prüft ob User eine Berechtigung hat |
| `getCSRAgentsWithRoles` | Alle CSR-Agenten mit Rollen-Info |
| `updateCSRUserRole` | Ändert CSR-Sub-Rolle eines Users |

**Beispiel-Response `getCSRRolePermissions`:**
```json
{
  "role": {
    "key": "fraud",
    "displayName": "Fraud Analyst",
    "canApprove": false
  },
  "permissionCount": 18,
  "permissions": [
    {
      "category": "viewing",
      "displayName": "Ansicht",
      "icon": "👁️",
      "permissions": [
        { "key": "viewCustomerProfile", "displayName": "Kundenprofil anzeigen" },
        ...
      ]
    },
    {
      "category": "fraud",
      "displayName": "Betrugsbekämpfung",
      "icon": "🔍",
      "permissions": [
        { "key": "viewFraudAlerts", "displayName": "Fraud-Alerts anzeigen" },
        { "key": "suspendAccountExtended", "displayName": "Konto erweitert sperren (>24h)", "requiresApproval": true },
        ...
      ]
    }
  ]
}
```

**Darstellung:** Im CSR-Web-Portal (Karte „Meine Berechtigungen“) werden **Kategorien** und **einzelne Berechtigungen** jeweils **alphabetisch nach `displayName`** (Locale `de`) sortiert – unabhängig von der Reihenfolge in der API-Response.

---

## 11. Bekannte Einschränkungen

1. **Kein Parse SDK** - Direkte REST Calls wegen Vite-Kompatibilität
2. **Self-signed SSL** - Browser-Ausnahme für HTTPS erforderlich
3. **Mock-Daten** - Finance/Security Dashboards zeigen teilweise Testdaten

---

## 12. Nächste Schritte

- [x] ~~HTTPS aktivieren~~ (Self-signed Zertifikat aktiv)
- [x] ~~Finanzen-Dashboard implementieren~~
- [x] ~~Sicherheits-Dashboard implementieren~~
- [x] ~~2FA Setup UI~~
- [x] ~~Unit Tests (Vitest)~~ – siehe `npm run test:run` (z. B. 191 Tests)
- [x] ~~ESLint 9 + CI~~ – `npm run lint` im Workflow-Job `admin-portal`
- [x] ~~E-Mail-Benachrichtigungen~~ (Brevo SMTP konfiguriert)
- [x] ~~CSR Web Panel~~ (Textbausteine, Ticket-Erstellung)
- [ ] Let's Encrypt (bei öffentlicher Domain)
- [ ] E2E Tests (Playwright)
- [ ] Echte Backend-Daten für Dashboards

---

## 13. Zugehörige Dokumentation

- [Admin Roles Separation](./09_ADMIN_ROLES_SEPARATION.md)
- [CSR Support Workflow](./06B_CSR_SUPPORT_WORKFLOW.md)
- [Customer Support System](../CUSTOMER_SUPPORT_SYSTEM.md)
- [Cursor Rules: Admin Portal](../.cursor/rules/admin-portal.md)
- [Backend Permissions (Rollen-Matrix)](../backend/parse-server/cloud/utils/permissions/constants.js)

---

## 14. UI Design & Style Guide – Admin Content Area

---

## 15. Doku-Checkpoint 2026-04-15: Steuerparameter-Hardening

### 15.1 Was wurde geändert

- Im Bereich **Konfiguration → Steuerparameter** werden standardmäßig nur zwei Parameter gezeigt:
  1. `Umsatzsteuer (MwSt.)`
  2. `Abgeltungsteuer` (Dropdown: `Kunde führt selbst ab` / `Plattform führt automatisch ab`)
- Die Detailwerte werden nur bei `Plattform führt automatisch ab` angezeigt:
  - `Abgeltungsteuersatz`
  - `Solidaritätszuschlag`
  - `Kirchensteuer` (automatisch aus Profil/Region abgeleitet, nicht als freier Satz konfigurierbar)
- Reihenfolge wurde fest auf **Umsatzsteuer vor Abgeltungsteuer** gesetzt.
- Bei ausstehender 4-Augen-Anfrage für `taxCollectionMode` ist der Dropdown gesperrt (konsistent mit anderen kritischen Parametern).

### 15.2 Warum

- Reduzierte Komplexität im Admin-UI (nur zentrale Steuerhebel sichtbar, Details bedingt).
- Klarere Governance im 4-Augen-Prozess.
- Vermeidung von Missverständnissen zwischen UI-Default und aktiv gespeichertem Konfigurationswert.

### 15.3 Source of Truth / Invarianten

- **Backend `Configuration.tax.taxCollectionMode` ist führend** (persistierter Live-Wert).
- UI-Defaults sind nur Fallback bei fehlendem/invalidem Payload.
- Zulässige Enum-Werte:
  - `customer_self_reports`
  - `platform_withholds`
- Unzulässige Werte werden fail-safe auf `customer_self_reports` normalisiert.

### 15.4 Mini-Testplan

1. Steuerparameter öffnen: `Umsatzsteuer` steht oberhalb `Abgeltungsteuer`.
2. Default `Kunde führt selbst ab`: Detailsteuern nicht sichtbar.
3. Auf `Plattform führt automatisch ab` wechseln: Detailsteuern sichtbar.
4. Ausstehende Änderung für `taxCollectionMode` erzeugen: Dropdown ist deaktiviert.
5. Seite neu laden: persistierter Modus bleibt sichtbar (kein Rückfall auf falschen UI-Default).

## 16. Doku-Checkpoint 2026-04-15: Legal Branding → Konfiguration

### 16.1 Zielbild

- **`{{APP_NAME}}` / Legal Branding** ist **kein** primärer Edit-Pfad mehr unter **AGB & Rechtstexte**.
- Stattdessen ist **`legalAppName`** ein **kritischer Konfigurationsparameter** (4‑Augen) unter **Konfiguration → Systemparameter**.

### 16.2 UX / Navigation

- **AGB & Rechtstexte:** Hinweis-Karte + Link nach `/configuration`.
- **Konfiguration:** zusätzliche Karte **Systemparameter** mit `App Name` (`legalAppName`).

### 16.3 Governance / Bypass-Schutz

- Cloud Function **`updateLegalBranding`** ist **deprecated** und wird serverseitig mit klarer Fehlermeldung blockiert.
- Kanonischer Write-Path bleibt **`requestConfigurationChange` → `approveConfigurationChange`**.

### 14.1 Layout-Übersicht

- **Grundlayout**: Zweispaltiges Layout mit fixer Sidebar links (ca. 260 px Breite) und einem flexiblen Content-Bereich rechts (`.admin-container`, `.sidebar`, `.main-content`).
- **Höhe**: Der Admin-Bereich nutzt die gesamte Viewport-Höhe (`min-height: 100vh`), Sidebar ist fixiert (`position: fixed; height: 100vh`).
- **Top-Bar**: Im Content-Bereich wird eine sticky Top-Bar (`.top-bar`) verwendet, die beim Scrollen sichtbar bleibt und Titel, Aktionen und Status anzeigt.
- **Content-Innenabstand**: Der eigentliche Inhaltsbereich (`.content`) verwendet einen großzügigen Rand (`padding: 30px`), um Karten, Tabellen und Formulare klar zu strukturieren.
- **Karten & Grids**: KPIs und Zusammenfassungen werden über `.stats-grid` (responsive Grid) und `.card` / `.stat-card` dargestellt.

### 14.2 Farbpalette (Hex-Codes)

**Grund- und Hintergrundfarben**

| Bereich                              | Variable / Klasse                   | Hex-Wert      | Beschreibung                                   |
|--------------------------------------|-------------------------------------|---------------|-----------------------------------------------|
| Seitenhintergrund (Content)         | `--background`, `body`, `.main-content` | `#1e293b`    | Dunkles Blau/Grau (Slate 800)                 |
| Content-Surface / Panels            | `--content-surface`, `.top-bar`     | `#334155`     | Dunkle Karten-/Panel-Farbe                    |
| Card-Hintergrund                    | `--card-bg`, `.card`, `.stat-card`  | `#334155` / `#334155e6` | Karten auf dunklem Hintergrund    |
| Sidebar-Hintergrund                 | `--sidebar-bg`, `.sidebar`          | `#1a1a2e`     | Sehr dunkler Blau-/Violett-Ton                |
| Tabellen-Hintergrund (Header)       | `th` in Dark-Content                | `#334155`     | Gleiche Surface-Farbe wie Cards               |

**Textfarben**

| Zweck                                | Variable / Klasse                               | Hex-Wert  |
|--------------------------------------|-------------------------------------------------|-----------|
| Primärer Text (Überschriften, H1/H2) | `--text-primary`, `main[data-content-area="dark"] h1,h2` | `#f1f5f9` |
| Sekundärer Text (Beschreibungen)     | `--text-secondary`, `.text-muted`, `p.text-gray-500`     | `#94a3b8` |
| Standard-Body-Text (helles Theme)    | `body` (Tailwind `text-fin1-dark`)             | `#0f172a` |
| Tabellentext in Dark-Cards           | `table th, table td`                           | `#e2e8f0` |

**Rahmen & Hover**

| Zweck                           | Variable / Klasse      | Hex-Wert             |
|---------------------------------|------------------------|----------------------|
| Standard-Border                 | `--border-color`       | `#475569`            |
| Tabellenzeilen Hover            | `tr:hover`             | `rgba(51,65,85,0.5)` |
| Input-Focus-Ring (Box-Shadow)   | `.form-control:focus`  | `rgba(0,102,204,0.25)` |

**Brand / Primärfarben**

| Zweck                            | Variable / Klasse                | Hex-Wert  |
|----------------------------------|----------------------------------|-----------|
| Admin-Primärfarbe (Legacy)      | `--primary-color`, `.btn-primary` | `#0066cc` |
| Admin-Primärfarbe Hover         | `--primary-hover`                | `#0052a3` |
| FIN1 Brand Blue (Portal)        | Tailwind `fin1-primary`          | `#1e3a5f` |
| FIN1 Sekundärblau               | Tailwind `fin1-secondary`        | `#2e5a8e` |
| Dark-Mode Brand-Text            | `.fin1-theme-dark .text-fin1-primary` | `#93c5fd` |

**Status- & Feedback-Farben**

| Zweck                     | Variable / Klasse                      | Hex-Wert / RGBA              |
|---------------------------|----------------------------------------|------------------------------|
| Erfolg (Buttons, Badges) | `--success-color`                      | `#28a745`                    |
| Erfolg (Tailwind)        | `bg-fin1-success`, `text-green-500`   | `#10b981`, `#22c55e`         |
| Warnung                  | `--warning-color`, Amber-Farben       | `#ffc107`, `#fde68a`, `#f59e0b` |
| Fehler / Danger          | `--danger-color`, Rot-Farben          | `#dc3545`, `#ef4444`, `#dc2626` |
| Status „connected“       | `.status-badge.connected`             | `rgba(16,185,129,0.2)`, `#6ee7b7` |
| Status „disconnected“    | `.status-badge.disconnected`          | `rgba(239,68,68,0.2)`, `#fca5a5` |

**Formulare, Tags & Badges**

| Element                        | Klasse / Verhalten                            | Hex-Wert / RGBA      |
|--------------------------------|-----------------------------------------------|----------------------|
| Input-Hintergrund (Dark-Content) | `.form-control`, `.search-box input`       | `#334155`            |
| Input-Placeholder              | `.form-control::placeholder`                 | `#94a3b8`            |
| Select (Dark-Card, bewusst hell) | `main[data-content-area="dark"] .fin1-card select` | Text `#1e3a5f`, BG `#e2e8f0` |
| Textinput in Cards (Dark, aber hell) | `.fin1-card input[type="text"/"search"/"email"]` | Text `#111827`, BG `#ffffff` |
| Standard-Tag                   | `.tag`                                       | BG `#334155`, Border `#475569`, Text `#f1f5f9` |
| Tag „email“                    | `.tag.email`                                 | BG `rgba(30,58,95,0.6)`, Text `#93c5fd` |
| Tag „default“                  | `.tag.default`                               | BG `rgba(120,80,40,0.5)`, Text `#fdba74` |

**Toasts, Modals & Scrollbars**

| Element                 | Klasse / Bereich                     | Hex-Wert / RGBA  |
|-------------------------|---------------------------------------|------------------|
| Modal-Overlay           | `.modal-overlay`                      | `rgba(0,0,0,0.5)`|
| Modal-Inhalt            | `.modal`                              | BG `#334155`, Border `#475569` |
| Toast-Hintergrund       | `.toast`                              | BG `#334155`, Border `#475569` |
| Toast-Erfolg-Markierung | `.toast.success` (linker Rand)        | `#10b981`        |
| Toast-Fehler-Markierung | `.toast.error` (linker Rand)          | `#ef4444`        |
| Scrollbar-Track         | `::-webkit-scrollbar-track`           | `#f3f4f6`        |
| Scrollbar-Thumb         | `::-webkit-scrollbar-thumb`           | `#d1d5db` / Hover `#9ca3af` |

### 14.3 Typografie & Abstände

- **Schriftfamilie**: Systemfont-Stack (Inter / -apple-system / BlinkMacSystemFont / Segoe UI / Roboto / Ubuntu / sans-serif).
- **Überschriften**: H1/H2 im Content-Bereich sind hell (`#f1f5f9`) und nutzen mittlere bis hohe Schriftstärken (z. B. `font-weight: 600`).
- **Lauftext**: Standard-Text im Dark-Content nutzt `#f1f5f9` bzw. `#94a3b8` für erklärende Texte; Tabellen- und Labeltexte sind bewusst leicht aufgehellt.
- **Abstände**: Karten und Tabellen verwenden vertikale Abstände von 16–24 px (`margin-bottom: 16px/24px`) und Innenabstände von 20–24 px (`padding: 20px/24px`), um Informationen visuell zu gruppieren.

### 14.4 Design-Rationale (Accounting / Compliance)

- **Lesbarkeit in Dark-Mode**: Alle geschäftsrelevanten Daten (KPIs, Summen, Rundungsdifferenzen, Status) werden mit hohem Kontrast dargestellt (heller Text auf dunklem Hintergrund bzw. helle Inputs mit dunklem Text), um Fehlablesungen bei Freigaben und Prüfungen zu minimieren.
- **Konsistente Brand-Farben**: FIN1-Primärblau (`#1e3a5f`) und die dazugehörigen Blautöne werden für Navigation, Primäraktionen und wichtige Kennzahlen eingesetzt, sodass Benutzer:innen Änderungen und Freigaben klar zuordnen können.
- **Status-Codierung**: Erfolg, Warnung und Fehler werden durch konsistente Grün-/Gelb-/Rot-Töne codiert; Badges (z. B. „Freigaben“, Verbindungsstatus, Compliance-Flags) nutzen dieselben Farben, damit kritische Zustände sofort visuell erkennbar sind.
- **Strukturierte Layout-Hierarchie**: Fixe Sidebar, sticky Top-Bar und kartengestütztes Layout sorgen für eine klare visuelle Hierarchie. Accounting- und Compliance-Workflows (4-Augen-Requests, Audit-Logs, Finanz-Kennzahlen) sind dadurch in klar abgegrenzten Bereichen platziert, was die Nachvollziehbarkeit und Revisionssicherheit unterstützt.

---

*Erstellt: 2026-02-02*
*Letzte Änderung: 2026-04-15*
