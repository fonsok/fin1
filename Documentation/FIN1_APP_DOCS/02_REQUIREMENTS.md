---
title: "FIN1 – Fachliche Spezifikation (Requirements)"
audience: ["Produkt", "BA", "QA", "Compliance", "Support"]
lastUpdated: "2026-02-01"
---

## Zweck

Dieses Dokument beschreibt die fachlichen Anforderungen von FIN1 in Form von **User Stories/Use Cases**, ergänzt um **fachliche Regeln**, **NFRs** und **Schnittstellen zu Fachabteilungen**.

## Ergänzung: Feature-Schutz (wichtig für Änderungen durch Dritte)

Wenn es nicht nur um “was soll das Produkt”, sondern um “was darf nicht kaputtgehen” geht:

- `02A_FEATURE_KATALOG_GUARDRAILS.md`

## 1) User Stories / Use Cases (nach Themen gruppiert)

### A) Registrierung, Login, Onboarding (KYC-ähnlich)

- **US-A1 Registrierung starten**
  Als neuer Nutzer möchte ich mich registrieren, damit ich die App nutzen kann.
  - **Akzeptanzkriterien**
    - E-Mail wird validiert und normalisiert (lowercase) (Backend: `Parse.User` Trigger).
    - Passwort-Policy wird serverseitig enforced (Parse passwordPolicy).
    - Nach Registrierung existieren Basisobjekte: `UserProfile`, `NotificationPreference`.

- **US-A2 Onboarding schrittweise abschließen**
  Als Nutzer möchte ich Onboarding-Schritte einzeln speichern, damit ich später fortsetzen kann.
  - **Akzeptanzkriterien**
    - Unterstützte Schritte: `personal`, `address`, `tax`, `experience`, `risk`, `consents`, `verification` (`completeOnboardingStep`).
    - Bei `verification` wird `onboardingCompleted=true` gesetzt.
    - KYC-Status wird korrekt gesetzt (`verified` wenn `kycApproved`, sonst `in_progress`).

- **US-A3 Profil anzeigen/ändern**
  Als Nutzer möchte ich mein Profil sehen und aktualisieren, damit meine Daten korrekt sind.
  - **Akzeptanzkriterien**
    - Profil liefert `User` + `UserProfile` + primäre `UserAddress` + letzte `UserRiskAssessment` (`getUserProfile`).
    - Profiländerungen sind serverseitig gespeichert (`updateProfile`).

### B) Investor: Trader Discovery, Investment, Portfolio

- **US-B1 Trader entdecken**
  Als Investor möchte ich Trader finden, um investieren zu können.
  - **Akzeptanzkriterien**
    - Discovery liefert nur aktive, verifizierte Trader (`discoverTraders` prüft `role=trader`, `status=active`, `kycStatus=verified`).
    - Ergebnis enthält riskClass (falls vorhanden), InvestorCount/AUM-Snapshot.

- **US-B2 Investment erstellen (Reservierung)**
  Als Investor möchte ich ein Investment erstellen, um Kapital in einen Trader-Pool zu geben.
  - **Akzeptanzkriterien**
    - Mindestinvestment: **€100**.
    - Investor kann nicht in eigenen Pool investieren (Trigger `Investment.beforeSave`).
    - Status startet als `reserved` mit 24h Ablauf (`reservationExpiresAt`).
    - Service Charge wird berechnet und `initialValue/currentValue` gesetzt (Trigger `Investment.beforeSave`).

- **US-B3 Investment bestätigen (Aktivierung)**
  Als Investor möchte ich ein reserviertes Investment bestätigen, damit es aktiv wird.
  - **Akzeptanzkriterien**
    - `confirmInvestment` erlaubt nur `reserved → active`.
    - Bei Aktivierung wird Wallet belastet (Trigger `Investment.afterSave` erzeugt `WalletTransaction`).

- **US-B4 Portfolio ansehen**
  Als Investor möchte ich mein Portfolio sehen, um Überblick über Investments/Performance zu haben.
  - **Akzeptanzkriterien**
    - Portfolio liefert Investments + Summary (totalInvested/totalCurrentValue/totalProfit/return%) (`getInvestorPortfolio`).

### C) Trader: Order/Trade, Depot/Holdings, Performance

- **US-C1 Order-Preview**
  Als Trader möchte ich vor dem Platzieren die Gebühren sehen, damit ich eine informierte Entscheidung treffe.
  - **Akzeptanzkriterien**
    - Preview liefert grossAmount, fees, netAmount (`calculateOrderPreview`).

- **US-C2 Order platzieren**
  Als Trader möchte ich Orders platzieren, damit Trades ausgeführt werden können.
  - **Akzeptanzkriterien**
    - Validierung: symbol, quantity>0, side ∈ {buy,sell}, orderType ∈ {market,limit,stop,stop_limit}.
    - Bei `limit/stop_limit`: limitPrice Pflicht; bei `stop/stop_limit`: stopPrice Pflicht (Trigger `Order.beforeSave`).
    - `orderNumber` wird serverseitig generiert (Trigger `Order.beforeSave`).

- **US-C3 Offene Trades & Historie**
  Als Trader möchte ich offene Trades und Historie sehen, um Positionen zu managen.
  - **Akzeptanzkriterien**
    - `getOpenTrades` liefert status ∈ {pending,active,partial}.
    - `getTradeHistory` ist paginiert und liefert `hasMore`.

- **US-C4 Holdings/Depot**
  Als Trader möchte ich mein Depot sehen, um Bestände zu überwachen.
  - **Akzeptanzkriterien**
    - `getHoldings` liefert aktive Holdings (class `Holding`, status `active`).

- **US-C5 Profitverteilung**
  Als Investor möchte ich bei Trade-Abschluss meinen Gewinnanteil erhalten, damit Performance fair verteilt wird.
  - **Akzeptanzkriterien**
    - Bei `Trade.status=completed` werden Pool-Anteile verteilt (Trigger `Trade.afterSave`).
    - Trader-Commission wird abgezogen; `Investment.currentValue/profit` werden aktualisiert.
    - Commission Record wird erzeugt (`Commission`).

### D) Wallet/Payments

- **US-D1 Wallet-Balance sehen**
  Als Nutzer möchte ich meinen Kontostand sehen.
  - **Akzeptanzkriterien**
    - Balance basiert auf letzter `WalletTransaction` mit `status=completed` (`getWalletBalance`).

- **US-D2 Einzahlen/Auszahlen anstoßen**
  Als Nutzer möchte ich Geld ein-/auszahlen.
  - **Akzeptanzkriterien**
    - Einzahlung min €10, max €100k (`requestDeposit`).
    - Auszahlung min €10; IBAN wird als Metadata gespeichert (`requestWithdrawal`).
    - Keine negative Balance (Trigger `WalletTransaction.beforeSave`).

- **US-D3 Compliance bei großen Transaktionen**
  Als Compliance möchte ich große Ein-/Auszahlungen automatisch erkennen.
  - **Akzeptanzkriterien**
    - Bei completed deposit/withdrawal ≥ €10k wird `ComplianceEvent` erstellt; ab €15k `requiresReview=true` (Trigger `WalletTransaction.afterSave`).

### E) Dokumente & Reporting

- **US-E1 Dokumente/Invoices/Statements abrufen**
  Als Nutzer möchte ich Dokumente abrufen und filtern.
  - **Akzeptanzkriterien**
    - `getDocuments` paginiert, optional nach `documentType`.
    - `getInvoices` paginiert, optional nach `invoiceType`.
    - `getAccountStatements` optional nach Jahr.

- **US-E2 Performance Reports**
  Als Trader/Investor möchte ich Performance-Reports sehen.
  - **Akzeptanzkriterien**
    - `getTraderPerformance`: nur role=trader.
    - `getInvestorPerformance`: Summen/Return% konsistent.

### F) Notifications

- **US-F1 Notification Inbox**
  Als Nutzer möchte ich Benachrichtigungen sehen und als gelesen markieren.
  - **Akzeptanzkriterien**
    - Neue Notifications sind `isRead=false`, `isArchived=false` (Trigger `Notification.beforeSave`).
    - `markNotificationRead` erlaubt nur eigene Notification.
    - `getUnreadNotificationCount` liefert total + byCategory.

### G) Customer Support (CSR), SLA, Surveys

- **US-G1 Ticket erstellen**
  Als Nutzer möchte ich ein Ticket erstellen, damit ich Hilfe bekomme.
  - **Akzeptanzkriterien**
    - `ticketNumber` wird generiert (Trigger `SupportTicket.beforeSave`).
    - SLA Targets werden anhand Priority gesetzt (Trigger `SupportTicket.afterSave`).
    - Nutzer erhält Notification.

- **US-G2 Ticket lösen & Survey**
  Als CSR möchte ich Tickets lösen und Feedback einholen.
  - **Akzeptanzkriterien**
    - Bei Status `resolved` wird Survey erstellt (Trigger `SupportTicket.afterSave`).
    - Nutzer erhält Notification `ticket_resolved`.

> **Hinweis (Prozess/Workflow)**: Der detaillierte CSR-Workflow inkl. Aufgabenverteilung (L1/L2/Fraud/Compliance/Tech/Teamlead), SLA-Handling, Auto-Eskalation und 4-Augen ist in `06B_CSR_SUPPORT_WORKFLOW.md` beschrieben.

### H) Admin & Compliance (4-Augen, User Management)

- **US-H1 Admin Dashboard**
  Als Admin möchte ich KPIs sehen.
  - **Akzeptanzkriterien**
    - `getAdminDashboard` liefert User/Investments/Trades/Support/Compliance-KPIs.
    - Zugriff nur für Rollen {admin, customer_service, compliance}.

- **US-H2 Nutzer suchen & Status ändern**
  Als Admin/CSR möchte ich Nutzer suchen und Status ändern.
  - **Akzeptanzkriterien**
    - `searchUsers` filtert nach E-Mail/CustomerId/role/status.
    - `updateUserStatus` erzeugt AuditLog (`AuditLog`).

- **US-H3 4-Augen-Freigaben**
  Als Admin/Compliance möchte ich Freigaben bearbeiten.
  - **Akzeptanzkriterien**
    - `getPendingApprovals` zeigt nicht eigene Requests.
    - `approveRequest` verhindert Selbstfreigabe und schreibt Audit.

### I) Legal (AGB/Datenschutz/Impressum) inkl. Audit Trail

- **US-I1 Aktuelle Rechtsdokumente abrufen**
  Als Nutzer möchte ich AGB/Datenschutz/Impressum sehen.
  - **Akzeptanzkriterien**
    - `getCurrentLegalDocument` liefert aktive Version nach language+documentType.
    - Legal Content ist server-driven und versioniert (`TermsContent`).

- **US-I2 Delivery/Consent auditieren**
  Als Compliance möchte ich nachweisen können, was ausgeliefert/akzeptiert wurde.
  - **Akzeptanzkriterien**
    - `logLegalDocumentDelivery` schreibt append-only Log (dedupe optional).
    - `recordLegalConsent` schreibt append-only Consent Record.
    - Löschung ist verboten (Trigger `legal.beforeDelete`).

## 2) Fachliche Regeln (Validierungen, Berechnungen, Zustandsautomaten, Berechtigungen)

### Rollen & Berechtigungen (Backend)

- **User.role**: `investor`, `trader`, `admin`, `customer_service`, `compliance`, `system`
- **Admin-Funktionen**: nur `admin|customer_service|compliance` (siehe `requireAdmin` in `functions/admin.js`)

### Zustandsautomaten (serverseitig enforced)

**Investment.status** (Trigger `Investment.beforeSave`):

- `reserved → active|cancelled`
- `active → executing|paused|closing|cancelled`
- `executing → active|paused`
- `paused → active|closing|cancelled`
- `closing → completed`
- `completed` terminal
- `cancelled` terminal

**Trade.status** (Trigger `Trade.beforeSave` / Ableitung über soldQuantity):

- Initial `pending`, danach typischerweise `active|partial|completed`

**Order.status** (Trigger `Order.beforeSave`):

- Initial `pending` (weitere Status je nach Ausführung: `executed`, `cancelled` etc.)

### Wallet-Regeln (Balance & Compliance)

- `WalletTransaction.balanceAfter` wird serverseitig berechnet (Trigger `WalletTransaction.beforeSave`).
- Negative Balance ist verboten.
- Große deposit/withdrawal erzeugen `ComplianceEvent` bei completion.

### Berechnungslogik (fachliche Leitplanken)

- Gebühren/Commission dürfen nicht “ad hoc” in UI berechnet werden; zentrale Services sind zu bevorzugen (iOS: `.cursor/rules/architecture.md`).
- Legal Docs: Hash basiert auf **serverseitig resolved** Content (Audit-Sicherheit).

## 3) Nicht-funktionale Anforderungen (NFR)

- **Security**
  - Keine Secrets im Repo (Backend `.env` außerhalb Git).
  - Token sicher speichern (iOS: Keychain).
  - CORS restriktiv konfigurieren; Produktion bevorzugt HTTPS.
- **Performance**
  - Mobile: flüssige Navigation, “first meaningful paint” < 2s (Ziel).
  - Backend: typische Cloud Function Antwort < 1s (Ziel, abhängig von DB).
- **Datenschutz**
  - Audit Logs / Compliance Events Retention 10 Jahre (iOS AuditLoggingService).
  - Minimierung personenbezogener Daten in Logs (keine Tokens/Passwörter).
- **Offline-Fähigkeit**
  - UI sollte server-driven Inhalte cachen (z.B. FAQ/Legal).
- **Usability**
  - Role-based Navigation, klare Fehlermeldungen (AppError-Standard).

## 4) Schnittstellen zu Fachabteilungen (Daten/Events)

### Reporting/Controlling

- Ereignisse: Investments (created/activated/completed), Trades (created/completed), WalletTransactions (completed), Invoices/Documents/Statements.
- Quellen: Parse Klassen (primär) + optional Postgres Analytics Schema (`backend/postgres/init/*.sql`).

### Compliance

- `ComplianceEvent` (AML/large_transaction etc.)
- Legal Delivery/Consent Logs (TermsContent + DeliveryLog + Consent)
- Audit Logs (User-/Admin-Aktionen, Statuswechsel)

### Marketing/CRM (optional)

- Segmente: Rollen, Onboarding-Status, Aktivität (Notifications/Events).
- Nur mit DSGVO-konformer Einwilligung/Legal Basis.

