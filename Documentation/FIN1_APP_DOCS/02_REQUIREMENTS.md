---
title: "FIN1 – Fachliche Spezifikation (Requirements)"
audience: ["Produkt", "BA", "QA", "Compliance", "Support"]
lastUpdated: "2026-06-26"
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

- **US-A1b Rechtliche Einwilligung vor Konto-Anlage (Legal Gate 1)**
  Als neuer Nutzer möchte ich AGB und Datenschutz **vor** der Persistierung meiner Kontaktdaten ausdrücklich akzeptieren.
  - **Akzeptanzkriterien**
    - iOS Contact-Step (Step 2): beide Toggles Pflicht (`SignUpLegalConsentSection`); „Konto anlegen“ disabled bis `hasRequiredLegalConsents`.
    - `POST /users` / frühe Kontoanlage sendet `acceptedTerms` und `acceptedPrivacyPolicy` nur wenn beide true (`UserFactory+ParseSignUp`).
    - Backend `userBeforeSave`: neue Nutzer ohne beide Consents werden abgelehnt.
    - Nach erfolgreicher Contact-Anlage und nach `finalizeRegistration` spiegelt iOS die Einwilligung in `DeviceLegalConsentStore` (kein redundantes Modal auf demselben Install).

- **US-A1d Rollenvereinbarung vor Registrierungsabschluss (Legal Gate 2)**
  Als Trader oder Investor mit Risikoklasse 7 möchte ich die für meine Rolle geltende Vereinbarung vollständig lesen und ausdrücklich akzeptieren, bevor ich die Registrierung abschließe und Trading/Investing nutze.
  - **Akzeptanzkriterien**
    - iOS Step 24 (`RoleAgreementStep`): Volltext der passenden Vereinbarung (`trader_agreement` / `investor_agreement`); Scroll-to-end (`ScrollToAcceptReader`) + Checkbox Pflicht; Abschluss-Button disabled bis beides erfüllt.
    - Vor `finalizeRegistration`: `recordRoleAgreementConsent` mit `version`, `deviceInstallId`, `documentHash`, `source: onboarding`; idempotent pro Nutzer/Version/Install.
    - `_User` erhält `acceptedTraderAgreement*` bzw. `acceptedInvestorAgreement*`; `getUserMe` liefert `roleAgreementRequired`, `roleAgreementAccepted`, `roleAgreementVersion`.
    - Optional: Bestätigungs-E-Mail mit PDF (`roleAgreementEmail.js`).
    - **Produkt-Zugriff:** `productAccessGate.assertProductAccessEligible` blockiert Trading (`placeOrder`, …) und Investing (`createInvestmentSplits`, …) ohne abgeschlossenes Onboarding, Gate-1-Consents **und** passende Rollenvereinbarung → `OPERATION_FORBIDDEN`.
    - Gate 2 ist **unabhängig** vom post-Login Device-Gate (TOS/Privacy pro Install); siehe `LEGAL_DOCS_AUDIT_TRAIL.md`.

- **US-A1c Retail-Rolle bei Registrierung festlegen (immutable nach Kontoanlage)**
  Als neuer Nutzer möchte ich auf dem Welcome-Schritt Investor oder Trader wählen; nach Kontoanlage soll diese Wahl nicht mehr änderbar sein.
  - **Akzeptanzkriterien**
    - Welcome (iOS Step 1): Rolle wählbar, solange noch kein Konto existiert (`!isAuthenticated`).
    - Contact (Step 2): gewählte Rolle wird mit `POST /users` auf `_User.role` persistiert.
    - Nach Kontoanlage: Welcome-Picker für Investor/Trader deaktiviert; kein Client-Sync der Rolle an den Server.
    - Resume: gespeicherte `userRole` im Onboarding-Blob überschreibt `_User.role` nicht (`lockAccountRole`); UI zeigt Server-Rolle.
    - Server: `saveOnboardingProgress` lehnt abweichende `userRole` ab; `userBeforeSave` lehnt Investor↔Trader-Wechsel auf bestehenden Konten ab.

- **US-RC1 Re-Consent TOS/Privacy (Post-Onboarding)**
  Als bestehender Nutzer möchte ich nach Aktivierung einer neuen AGB- oder Datenschutz-Version diese erneut bestätigen, bevor ich Trading/Investing weiter nutze.
  - **Akzeptanzkriterien**
    - Admin aktiviert höhere `TermsContent`-Version (`setActiveTermsContent`).
    - `getRequiredReConsents` / `getUserMe.requiredReConsents` listet Eintrag mit `blocking: true`, wenn `_User.accepted*Version` gesetzt und älter als aktiv.
    - iOS: nach Login zuerst ggf. Device-Gate, dann `ReConsentModalView` oder Device-Gate allein bei TOS/Privacy-Bump (beides blockiert korrekt).
    - Accept: `recordLegalConsent` mit `source: app`; `_User.accepted*Version` aktualisiert; `LegalConsent` append-only.

- **US-RC2 Re-Consent Role Agreement**
  Als Investor/Trader möchte ich nach Aktivierung einer neuen Rollenvereinbarungs-Version den Text scrollen und ausdrücklich zustimmen.
  - **Akzeptanzkriterien**
    - `investor_agreement` / `trader_agreement` Version-Drift in `requiredReConsents` mit `requiresScrollToAccept: true`.
    - iOS: `RoleAgreementReConsentView` (Scroll + Checkbox) → `recordRoleAgreementConsent` mit `source: app`.
    - Nach Accept: `requiredReConsents` leer; Investment/Trading wieder frei (sofern sonstige Gates passieren).

- **US-RC3 Server erzwingt Re-Consent**
  Als Plattform möchte ich regulierte Cloud Functions ohne aktuelle Legal-Versionen ablehnen.
  - **Akzeptanzkriterien**
    - `assertProductAccessEligible` prüft `resolveRequiredReConsents` vor Trading/Investment (`createInvestmentSplits`, `placeOrder`, …).
    - Fehler: `OPERATION_FORBIDDEN` mit spezifischer Meldung (z. B. *Terms of Service must be re-accepted (version X required).*).
    - Legacy-Nutzer ohne Versionsfelder: kein erzwungenes Re-Consent (Grandfather).

- **US-RC4 Compliance-Audit Re-Consent**
  Als Compliance möchte ich jede Post-Onboarding-Zustimmung nachvollziehen.
  - **Akzeptanzkriterien**
    - `LegalConsent` mit `source: app`, Version, IP, User-Agent, `deviceInstallId`, `appVersion`.
    - Abnahmeprotokoll: [`RELEASE_ABNAHME_RE_CONSENT.md`](../RELEASE_ABNAHME_RE_CONSENT.md).

- **US-A2 Onboarding schrittweise abschließen**
  Als Nutzer möchte ich Onboarding-Schritte einzeln speichern, damit ich später fortsetzen kann.
  - **Akzeptanzkriterien**
    - Unterstützte Schritte: `personal`, `address`, `tax`, `experience`, `risk`, `consents`, `verification` (`completeOnboardingStep`).
    - Bei `verification` wird `onboardingCompleted=true` gesetzt.
    - KYC-Status wird korrekt gesetzt (`verified` wenn `kycApproved`, sonst `in_progress`).
    - **Schritt `experience` (iOS Step 16 — Anlageerfahrung):**
      - Pflichtfelder inkl. Zertifikate/Derivate (16c): Transaktionsanzahl, Betrag, Haltedauer (sofern Anzahl ≠ `none`).
      - **RC-5-Gate 16c (Client-Berechnung, rollenspezifisch):** Ohne passendes Derivatives-Profil wird eine berechnete RK 5 auf **max. RK 4** gekappt (`cappedForRiskClass5DerivativesGate`).
        - **Investor:** mindestens 1–10 Transaktionen, €1.000–10.000 investiert, Haltedauer Tage bis Wochen (höhere Werte zulässig).
        - **Trader:** 50+ Transaktionen, ≥ €10.000 investiert, Haltedauer Minuten bis Stunden.
      - **Investor-Sonderpfad RK 5:** bei Score unter 19 möglich, wenn nicht arbeitslos + Investor-16c-Gate + Rendite ≥ 50 %.
      - **Server-Spiegelung (einmalig beim Schritt `risk`/`verification`):** `riskClass5DerivativesGate.js` kappt `finalRiskClass`/`calculatedRiskClass` 5 → 4 ohne passendes 16c-Profil (`user.riskTolerance`); O(1), kein Rechenpfad pro Trade.
      - **Signup-Last:** `saveOnboardingProgress` schreibt ein Fortschrittsdokument pro Nutzer (kein Dokument pro UI-Schritt), überspringt redundante `_User`-Saves, limitiert Save-Frequenz; Indexes `onboarding_signup_indexes_v1`; iOS coalesced Saves (~400 ms).
    - **Schritt `risk` (iOS Step 17 — Gewinnziel, Verlusttragfähigkeit & Wissenstest):**
      - Pflicht bei Abschluss: `leveragedProductsTotalLossRiskAcknowledged` (boolean), `leveragedProductsKnowledgeTestAnswers` (alle Fragen der aktuellen Version beantwortet, Optionen A–D).
      - Optional: `leveragedProductsKnowledgeTestVersion`, `leveragedProductsKnowledgeTestPassed`, `desiredReturn`, berechnete/finale Risikoklasse.
      - Server prüft **Vollständigkeit** der Antworten (Joi + `leveragedProductsKnowledgeTest.js`), **nicht** ob Antworten inhaltlich korrekt sind — Korrektheit ist Client-Produktlogik.
      - **Fachregel RK1:** Wenn Totalverlust mit **Nein** beantwortet oder Wissenstest beantwortet aber nicht bestanden → finale Risikoklasse **1** (`requiresConservativeRiskClassFromOnboarding`). iOS synchronisiert `userSelectedRiskClass` **reaktiv** bei Ja/Nein- und Quiz-Antworten (`updateLeveragedProductsTotalLossRiskAcknowledged`, `updateLeveragedProductsKnowledgeTestAnswer` → `syncOnboardingRiskClassSelection`).
      - Falsche Quiz-Antwort: Lernhinweis in der App, **kein** Blocker für „Weiter“.
    - **Schritt 22 (Hinweis Risikoklassifizierung, iOS):** RK 1–4 → Abbruch zur Landing; RK 5–6 → Landing nur ohne manuelle RK-Erhöhung; RK 7 → Schritt 23 → 24 (Role Agreement) → Finalize.
    - Audit: Beim Abschluss von `risk` schreibt `OnboardingAudit` u. a. Totalverlust-Bestätigung, Wissenstest-Version/-Antworten/-bestanden, `finalRiskClass` (`onboarding.js` → `buildAuditAnswers`).

- **US-A2b Onboarding — Dev/Test (nur Entwicklung)**
  Als Entwickler möchte ich den Sign-Up-Flow auf iobox/debug schnell durchklicken können.
  - **Akzeptanzkriterien**
    - iOS `#if DEBUG`: Prefill inkl. **TOS + Privacy** auf Contact (`prefillTestData`), automatische Verifikation (`SignUpCoordinator+DebugPrefill.swift`, `TestUserConstants.signupTest*`).
    - OTP `000000` wird serverseitig akzeptiert, wenn `NODE_ENV !== production` **oder** `ALLOW_DEV_ONBOARDING_OTP_BYPASS=true` (siehe `onboardingDevOtpBypass.js`, `backend/env.example`).

- **US-A3 Profil anzeigen/ändern**
  Als Nutzer möchte ich mein Profil sehen und aktualisieren, damit meine Daten korrekt sind.
  - **Akzeptanzkriterien**
    - Profil liefert `User` + `UserProfile` + primäre `UserAddress` + letzte `UserRiskAssessment` (`getUserProfile`).
    - Nach Login bzw. Aktualisierung des lokalen Nutzerobjekts synchronisiert die App den Server-`User`-Snapshot per `getUserMe` (ein Aufruf; u. a. Kundennummer, KYC, Onboarding/KYB); `getUserProfile` bleibt für die vollständige Profil-UI.
    - Profiländerungen sind serverseitig gespeichert (`updateProfile`).

### B) Investor: Trader Discovery, Investment, Investment-Übersicht

- **US-B1 Trader entdecken**
  Als Investor möchte ich Trader finden, um investieren zu können.
  - **Akzeptanzkriterien**
    - Discovery liefert nur aktive, verifizierte Trader (`discoverTraders` prüft `role=trader`, `status=active`, `kycStatus=verified`).
    - Ergebnis enthält riskClass (falls vorhanden), InvestorCount/AUM-Snapshot.

- **US-B2 Investment erstellen (Reservierung)**
  Als Investor erstelle ich ein Investment, um denselben Trade eines von mir ausgewählten Traders durch die {{APP_NAME}} simultan ausführen zu lassen.
  - **Akzeptanzkriterien**
    - Mindestinvestment: **€100**.
    - Investor kann nicht in eigenen Pool investieren (Trigger `Investment.beforeSave`).
    - Status startet als `reserved` mit 24h Ablauf (`reservationExpiresAt`).
    - Service Charge wird berechnet und `initialValue/currentValue` gesetzt (Trigger `Investment.beforeSave`).

- **US-B3 Investment bestätigen (Aktivierung)**
  Als Investor möchte ich ein reserviertes Investment bestätigen, damit es aktiv wird.
  - **Akzeptanzkriterien**
    - `confirmInvestment` erlaubt nur `reserved → active`.
    - Bei Aktivierung wird das Konto belastet (Trigger `Investment.afterSave` erzeugt Kontobuchung).

- **US-B4 Investment-Übersicht ansehen**
  Als Investor möchte ich meine Investment-Übersicht sehen, um Überblick über Investments/Performance zu haben.
  - **Akzeptanzkriterien**
    - Die Übersicht liefert Investments + Summary (totalInvested/totalCurrentValue/totalProfit/return%) (`getInvestorPortfolio`).

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
    - Nach abgeschlossener Kauforder zeigt die Positions-Kachel optional **Investment-Pool** (`active` / `-`) — Admin → Anzeige → `showTraderDashboardInvestmentActiveStatus` (4-Augen; Standard: an). Semantik: `DepotPositionPoolStatusResolver` (nur Mirror-Leg / dokumentierte Teilnahme = `active`; reserviert ohne Paired Buy = `-`). Siehe `03_TECHNISCHE_SPEZIFIKATION.md` §6.5a.

- **US-C5 Profitverteilung**
  Als Investor möchte ich bei Trade-Abschluss meinen Gewinnanteil erhalten, damit Performance fair verteilt wird.
  - **Akzeptanzkriterien**
    - Bei `Trade.status=completed` werden Pool-Anteile verteilt (Trigger `Trade.afterSave`).
    - Trader-Commission wird abgezogen; `Investment.currentValue/profit` werden aktualisiert.
    - Commission Record wird erzeugt (`Commission`).

### D) Konto (Kontostand, Ein- und Auszahlungen)

Der Nutzer hat ein **normales Konto** (kein separates Konto-Feature). Kontostand und Ein-/Auszahlungen werden über dieses Konto abgewickelt.

- **US-D1 Kontostand sehen**
  Als Nutzer möchte ich meinen Kontostand sehen.
  - **Akzeptanzkriterien**
    - Kontostand wird serverseitig geführt und angezeigt.

- **US-D2 Einzahlen/Auszahlen anstoßen**
  Als Nutzer möchte ich Geld ein-/auszahlen.
  - **Akzeptanzkriterien**
    - Einzahlung min €10, max €100k.
    - Auszahlung min €10; IBAN wird als Metadata gespeichert.
    - Keine negative Balance (serverseitig enforced).

- **US-D3 Compliance bei großen Transaktionen**
  Als Compliance möchte ich große Ein-/Auszahlungen automatisch erkennen.
  - **Akzeptanzkriterien**
    - Bei completed deposit/withdrawal ≥ €10k wird `ComplianceEvent` erstellt; ab €15k `requiresReview=true`.

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
    - `getPendingApprovals` zeigt nicht eigene Requests („Freigaben erteilen“ nur Anträge anderer; „Eigene Anträge“ nur eigene pending).
    - In der Sidebar zeigt „Freigaben“ ein rotes Badge mit der Anzahl offener Anträge (Anträge zur Freigabe + eigene pending), solange welche offen sind.
    - `approveRequest` verhindert Selbstfreigabe und schreibt Audit.

### I) Legal (AGB/Datenschutz/Impressum) inkl. Audit Trail

- **US-I1 Aktuelle Rechtsdokumente abrufen**
  Als Nutzer möchte ich AGB/Datenschutz/Impressum sowie — im Onboarding — die rollenspezifische Vereinbarung sehen.
  - **Akzeptanzkriterien**
    - `getCurrentLegalDocument` liefert aktive Version nach `language` + `documentType` (`terms|privacy|imprint|trader_agreement|investor_agreement`).
    - Legal Content ist server-driven und versioniert (`TermsContent`).

- **US-I2 Delivery/Consent auditieren**
  Als Compliance möchte ich nachweisen können, was ausgeliefert/akzeptiert wurde.
  - **Akzeptanzkriterien**
    - `logLegalDocumentDelivery` schreibt append-only Log (dedupe optional).
    - `recordLegalConsent` schreibt append-only Consent Record mit `source: app`.
    - `recordRoleAgreementConsent` schreibt append-only Consent für `trader_agreement`/`investor_agreement` (Onboarding oder expliziter App-Accept).
    - Onboarding-Schritt `consents` schreibt zusätzlich `LegalConsent` mit `source: onboarding` (`persistOnboardingLegalConsents`).
    - `getDeviceLegalConsentAcknowledgements` exportiert nur `source: app` — Onboarding-Zeilen zählen nicht als Device-Bestätigung.
    - iOS Device-Gate: nach Login blockiert `TermsAcceptanceModalView`, bis TOS **und** Privacy für die aktive Version auf diesem Install bestätigt sind (`DeviceLegalConsentStore`).
    - Löschung ist verboten (Trigger `legal.beforeDelete`).

## 2) Fachliche Regeln (Validierungen, Berechnungen, Zustandsautomaten, Berechtigungen)

### Rollen & Berechtigungen (Backend)

- **User.role**: `investor`, `trader`, `admin`, `customer_service`, `compliance`, `system`
- **Retail-Rolle (`investor`/`trader`):** genau **eine** Rolle pro Konto; gesetzt bei Registrierung (Contact/`POST /users`); **nicht änderbar** danach (Trigger + Onboarding-Progress-Guard).
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

### Konto-Regeln (Kontostand & Compliance)

- Kontostand wird serverseitig geführt; negative Balance ist verboten.
- Große Ein-/Auszahlungen erzeugen `ComplianceEvent` bei completion.

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

- Ereignisse: Investments (created/activated/completed), Trades (created/completed), Kontobewegungen, Invoices/Documents/Statements.
- Quellen: Parse Klassen (primär) + optional Postgres Analytics Schema (`backend/postgres/init/*.sql`).

### Compliance

- `ComplianceEvent` (AML/large_transaction etc.)
- Legal Delivery/Consent Logs (TermsContent + DeliveryLog + Consent)
- Audit Logs (User-/Admin-Aktionen, Statuswechsel)

### Marketing/CRM (optional)

- Segmente: Rollen, Onboarding-Status, Aktivität (Notifications/Events).
- Nur mit DSGVO-konformer Einwilligung/Legal Basis.

