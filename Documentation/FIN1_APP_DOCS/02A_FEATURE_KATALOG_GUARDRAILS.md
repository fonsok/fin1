---
title: "FIN1 – Feature-Katalog & Guardrails (Schutz funktionierender Implementationen)"
audience: ["Entwicklung", "QA", "Produkt", "Support", "Compliance"]
lastUpdated: "2026-06-23"
---

## Zweck

Dieses Dokument beschreibt die **bereits funktionierenden FIN1-Features** so, dass Dritte sie **nicht versehentlich brechen**:

- **Was macht das Feature?** (Scope, Zielgruppe)
- **Wie ist es im Code verdrahtet?** (Entry Points, zentrale Dateien/Services)
- **Was ist “protected behavior”?** (muss unverändert funktionieren)
- **Was darf nur mit hoher Vorsicht geändert werden?** (Contracts, APIs, Security/Privacy)
- **Welche Minimal-Checks/Testfälle sind Pflicht**, wenn man es anfasst?

> Source of Truth: Code + Config. Dieses Dokument ist absichtlich “konservativ”: lieber klare Schutzregeln als kreative Neuinterpretationen.

## 1) Globale Guardrails (gelten für alle Features)

- **MVVM + DI ist nicht optional**
  - Views importieren keine Services direkt; ViewModels bekommen Protokolle injiziert.
  - Keine `.shared`/Singletons außerhalb Composition Root (Ausnahmen nur dort, wo bereits bewusst erlaubt).
- **Compliance/Privacy first**
  - Kein Cross-User-Leak (z.B. Notifications/Dokumente müssen nach `userId` gefiltert werden).
  - Keine sensitiven Daten in Logs (Tokens, PII, Secrets).
- **Contracts sind stabil**
  - Cloud Function Namen sind API-Contract (z.B. `getFAQCategories`, `getCurrentTerms`): nicht ändern ohne koordinierte Migration.
  - NotificationCenter Events sind Contract (`.userDidSignIn`, `.userDidSignOut`, `.userDataDidUpdate`): nicht stillschweigend entfernen/umbenennen.
- **Regressionsschutz**
  - Änderungen an einem Feature brauchen einen minimalen Regression-Check (siehe pro Feature).
  - Refactorings ohne Verhaltensänderung sind ok – aber nur, wenn die “Protected Behaviors” bleiben.

### 1.1 Financial Calculations & Accounting Guardrails (Trading/Investing/Cash Balance/Invoices/Bills/Statements)

Diese Regeln schützen **bereits korrekte Finanzwerte** vor “Formel-Drift” (sehr häufige, teure Regression).

- **Single Source of Truth ist Pflicht (keine Parallel-Formeln)**
  - **Constants**: `FIN1/Shared/Models/CalculationConstants.swift` ist die zentrale Quelle für Raten/Limits/Default-Werte (Fallback-Werte).
- **Konfigurierbare Rates**: `ConfigurationService` verwaltet admin-konfigurierbare Finanzparameter (z.B. `appServiceChargeRate`, `traderCommissionRate`, `appCommissionRate`, `investorCommissionRateTotal`) mit Fallback auf `CalculationConstants` Defaults. Im Admin-Portal werden die drei Provisions-Rates als **eine Karte** mit Aufteilungs-Dropdown bearbeitet (`requestCommissionRateBundleChange`).
  - **Fees**: ausschließlich `FIN1/Shared/Services/FeeCalculationService.swift` (`createFeeBreakdown`, `calculateTotalFees`).
  - **Profit (Trader, aus Invoices, ohne Taxes)**: `FIN1/Shared/Services/ProfitCalculationService.swift` (`calculateTaxableProfit`), verwendet `Invoice.nonTaxTotal` (siehe `FIN1/Shared/Extensions/Invoice+Calculations.swift`).
  - **Taxes**: ausschließlich `FIN1/Features/Trader/Models/InvoiceTaxCalculations.swift` (`InvoiceTaxCalculator.*`).
  - **Guard/Validation** (Regression-Tripwire): `FIN1/Shared/Services/CalculationGuardService.swift` + `CalculationValidationService.swift`.
  - **Investor Collection Bill (authoritativ)**: `FIN1/Features/Investor/Services/InvestorCollectionBillCalculationService.swift`.
  - **Investor gross profit (für Commission/Breakdowns)**: `FIN1/Shared/Services/InvestorGrossProfitService.swift` (delegiert bewusst an Collection-Bill-Logik).
  - **Commission**: `FIN1/Shared/Services/CommissionCalculationService.swift` (Commission nur auf \(grossProfit > 0\)).
  - **Account Statements**:
    - Investor: `FIN1/Shared/Accounting/InvestorAccountStatementBuilder.swift`
    - Trader: `FIN1/Shared/Accounting/TraderAccountStatementBuilder.swift`
    - Monthly Docs: `FIN1/Shared/Services/MonthlyAccountStatementGenerator.swift` (@MainActor; skip current month, no duplicates, Document validation). **Scheduling:** nach parallelem Preload in `FIN1/FIN1App.swift` via **`MonthlyStatementPrefetch`** (non-blocking `@MainActor` `Task`, max. eine laufende Ausführung). Details: `Documentation/AccountStatementsAndReports.md`.

- **Do-not-touch: Datenquellen-Hierarchie (entscheidet, welche Zahlen “gewinnen”)**
  - **Trader Profit/PNL Display**: `Trade.displayProfit` in `FIN1/Features/Trader/Models/Trade.swift` ist der Contract.
    - Fallback Chain: `Trade.calculatedProfit` (invoice-verified, gespeicherter Single Source) → Order-basierte Fallback-Berechnung → 0.
    - Nicht “mal eben” umstellen, sonst sind Trades-Overview vs Detail vs Steuer/Breakdown inkonsistent.
  - **Investor Collection Bill Buy-Leg**: **Investment-Kapital ist Source of Truth**, nicht Invoice-Quantity.
    - Buy-Amount wird so gewählt, dass **Securities Value + Fees \(\le\) Investment Capital** (Accounting-Prinzip).
    - Quantity wird **ganzzahlig** gerundet (keine fractional pieces) und Residual bleibt **< buy price** (Maximierung der Kapitalnutzung).
  - **Fee Items / Tax Items**:
    - Profit-Berechnungen müssen **Tax Items ausschließen** (nicht per “handmade filter” irgendwo im UI).
    - Nutze `Invoice.nonTaxItems`/`nonTaxTotal` aus `Invoice+Calculations`.

- **Cash Balance: welche Balance ist gemeint?**
  - **Trader “live cash”** (UI/Validierung): `FIN1/Shared/Services/CashBalanceService.swift` (Kontostand/Live-Updates).
  - **Investor Balance + Ledger**: `FIN1/Features/Investor/Services/InvestorCashBalanceService.swift` ist ledgerbasiert (Investment-Events + optional Konto).
  - **Trader Balance + Commission Tracking**: `FIN1/Features/Trader/Services/TraderCashBalanceService.swift`.
  - **No-Go**: Balance im UI durch “Summieren von Invoices” oder “Summieren von Trades” rekonstruieren – dafür existieren Builder/Services.

- **Account Statement / Monthly Statement ist ein Dokument-Contract**
  - Der Monatsgenerator erzeugt nur **abgeschlossene Monate** (current month wird übersprungen) und erstellt nichts doppelt.
  - Die Snapshot-Builder sind **die** Quelle für Opening/Closing/Running Balance; nicht in ViewModels nachbauen.

- **Minimal-Checks (wenn du irgendeine Calculation anfässt)**
  - Trades-Übersicht vs Trade-Detail vs Collection-Bill/Breakdown zeigen **identische** Profit/ROI-Werte (keine 0,xx-€ Drift).
  - Investor: Investment Amount + App Service Charge + Minimum Reserve Validation bleibt korrekt.
  - Account Statement: Opening/Closing Balance plausibel, Running Balance stimmt, Filter (Range/Monat) bleibt korrekt.
  - Konto/Live Updates: Balance-Updates brechen nicht.

- **Weiterführende Implementations-Dokus (aktuell, code-nah)**
  - `Documentation/CALCULATION_SCHEME_PROTECTION.md`
  - `Documentation/CALCULATION_CONSISTENCY_AND_MVVM_IMPLEMENTATION.md`
  - `FIN1/Documentation/INVESTOR_COLLECTION_BILL_CALCULATION_DETAILED.md`
  - `Documentation/AccountStatementsAndReports.md`

## 2) Feature-Landkarte (wo liegt was?)

- **Authentication / Get Started / Sign In / Sign Up**: `FIN1/Features/Authentication/`
- **Investor (Investing/Portfolio/Discovery/Watchlist)**: `FIN1/Features/Investor/`
- **Trader (Trading/Depot/Orders/Trades)**: `FIN1/Features/Trader/`
- **Customer Support (CSR)**: `FIN1/Features/CustomerSupport/`
- **Dashboard**: `FIN1/Features/Dashboard/`
- **Admin**: `FIN1/Features/Admin/`
- **Shared: Profile, Notifications, Legal, Services**: `FIN1/Shared/`

## 3) Feature-Details (mit Protected Behaviors)

### 3.1 Get Started / Landing (Entry für neue Nutzer)

- **Entry Point**
  - `FIN1/Features/Authentication/Views/LandingView.swift`
- **UI/Flows**
  - `Get Started` → öffnet **Sign Up** als `fullScreenCover` (`SignUpView`).
  - `Sign In` → öffnet **Login** als `sheet` (`DirectLoginView`).
  - Landing enthält:
    - App-Advantages Section
    - FAQ Section (`LandingFAQView`)
    - Legal Links (Terms/Privacy/Imprint) als Sheets, server-driven via `TermsContentService`.
- **Protected Behaviors**
  - Landing muss **ohne Backend** robust rendern (keine Crashes wenn Services/Netz fehlen).
  - Responsive Design System bleibt durchgängig (`ResponsiveDesign.*`), keine “Magic Numbers”.
  - Legal Links (Terms/Privacy/Imprint) müssen weiterhin erreichbar sein (Compliance/Trust).
- **Wenn du hier etwas änderst, musst du prüfen**
  - Navigation: Get Started / Sign In / Legal Sheets öffnen korrekt.
  - Landing FAQ lädt und fällt sauber zurück (siehe FAQ Feature).

### 3.2 Sign In / Auth Root (Gatekeeper)

- **Entry Points**
  - `FIN1/Features/Authentication/Views/AuthenticationView.swift` (Root Gate)
  - `FIN1/Shared/Components/Navigation/MainTabView.swift` (nach abgeschlossenem Onboarding)
- **Protected Behaviors**
  - Auth Gate:
    - Wenn `services.userService.isAuthenticated == false` → Landing.
    - Wenn authenticated **und** `onboardingCompleted == true` → `MainTabView`.
    - Wenn authenticated, Onboarding **noch offen** → neutraler Placeholder (`OnboardingInProgressPlaceholder`); SignUp-`fullScreenCover` bleibt oben — **kein** Dashboard/Depot/SLA im Hintergrund.
  - **Retail-Background (iOS, seit 2026-06):** `AppRootContent.refreshUserScopedData`, `DashboardStatsViewModel.refreshAllData` und Monats-Kontoauszug-Prefetch laufen für Retail (`investor`/`trader`) erst nach `onboardingCompleted`. **SLA-Monitoring** (`SLAMonitoringService`) nur für `admin` / `customerService`.
  - **Blocking Terms Acceptance (Device-Gate)**:
    - Nach Login/authenticated Session: `AuthenticationView.evaluateLegalConsentRequirement` prüft **pro Install**, ob TOS **und** Privacy für die **aktive Dokumentversion** lokal bestätigt wurden (`DeviceLegalConsentStore` + `TermsAcceptanceService`).
    - Falls ein oder beide fehlen: `TermsAcceptanceModalView` blockiert die App (Overlay); **beide** müssen per „Accept“ bestätigt werden — ein Teil-Accept schließt das Modal nicht.
    - `getDeviceLegalConsentAcknowledgements` liefert nur `source: app`; Onboarding-`LegalConsent` (`source: onboarding`) darf nicht in den Device-Store importiert werden.
    - Server-Sync (`syncAcknowledgementsFromServer`) nur beim vollen Gate-Check (Login), nicht bei jedem `userDataDidUpdate` nach Teil-Accept.
    - Version-Auflösung: Cache → Server → Profil-Version → Bundled Fallback (`LegalConsentVersionResolver`).
  - NotificationCenter Contracts:
    - `.userDidSignIn` schaltet UI auf “authenticated”
    - `.userDidSignOut` schaltet UI zurück auf Landing und entfernt Terms Overlay
- **Änderungsverbote (typisch unabsichtlich kaputt gemacht)**
  - Terms Acceptance darf nicht “optional” werden (Compliance).
  - `.userDidSignIn/.userDidSignOut` nicht umbenennen/entfernen ohne Migration aller Sender/Listener.

### 3.3 Sign Up / Onboarding (mehrstufig)

- **Entry Points**
  - `FIN1/Features/Authentication/Views/SignUp/SignUpView.swift`
  - Step-Modelle: `FIN1/Features/Authentication/Views/SignUp/Components/Models/*`
  - iOS Step 17 (UI): `DesiredReturnStep.swift` — Enum `SignUpStep.desiredReturn`
  - Wissenstest-SSOT (iOS): `LeveragedProductsKnowledgeTest.swift`
  - Wissenstest-SSOT (Backend): `backend/parse-server/cloud/utils/leveragedProductsKnowledgeTest.js`
- **Protected Behaviors**
  - Registrierung bleibt **multi-step** (UI + Validation), inkl. Risk/Experience/Declarations.
  - Validierungen bleiben in Services/ViewModels (nicht in Views).
  - Risiko-/Erfahrungslogik bleibt konsistent (siehe `.cursor/rules/compliance.md` und Auth Services).
  - **Legal Gate 1 (Contact, iOS Step 2):** `SignUpLegalConsentSection` — TOS **und** Privacy müssen aktiv gesetzt sein, bevor `createAccountIfNeeded` / `POST /users` läuft (`hasRequiredLegalConsents`). Button-Text: „Konto anlegen“. Step 3 Copy: „Konto angelegt“ / „Registrierung gestartet“ (bewusst nicht „Konto eröffnet“, solange Onboarding offen ist).
  - Nach Contact-Account und nach `finalizeRegistration` spiegelt `mirrorSignupLegalGateToDeviceStore` die Gate-1-Einwilligung in `DeviceLegalConsentStore` (kein redundantes Post-Registration-Modal auf demselben Install).
  - **Retail-Rolle (Investor/Trader) — immutable nach Kontoanlage:**
    - **Vor Contact (Welcome, iOS Step 1):** Rolle nur lokal in `SignUpData.userRole` wählbar.
    - **Bei Contact:** `POST /users` / `createEarlyAccountUser` persistiert `_User.role` — ab dann SSOT auf dem Server.
    - **Nach Kontoanlage:** Rolle **nicht** mehr änderbar — weder in der UI (`WelcomeStep.isRoleSelectionLocked`), noch per `saveOnboardingProgress` (abweichende `userRole` im Blob → `OPERATION_FORBIDDEN`), noch per `_User.save` (`userTriggerBeforeSave` blockiert Investor↔Trader).
    - **Resume:** `restoreFromSavedData(..., lockAccountRole: true)` ignoriert gespeicherte `userRole` im Blob; `applyServerRoleToSignUpData()` gleicht UI/Coordinator mit `_User.role` ab (kein Client-Sync zurück zum Server).
  - **Step 20 (Terms):** keine Duplikat-Consent-Toggles mehr; RC7 zeigt nur read-only Consent-Status mit Link zurück zu Contact bei Lücken.
  - **Step 16 (Experience):** bei Transaktionsanzahl `none` werden €-/Zeit-Follow-up-Picker ausgeblendet und Werte geleert; Screen scrollt beim Step-Wechsel nach oben.
  - **Step 16c (Zertifikate & Derivate) — RC-5-Gate (rollenspezifisch, iOS):**
    - SSOT: `SignUpDataRiskCalculation.swift` → `meetsRiskClass5DerivativesExperienceCriteria`, `cappedForRiskClass5DerivativesGate`.
    - Berechnete RK 5 wird ohne passendes Profil auf **max. RK 4** gekappt.
    - **Investor** (`meetsInvestorRiskClass5DerivativesExperienceCriteria`) — Mindestprofil:
      - Transaktionen: **1–10** (oder höher: 10–50, 50+)
      - Investitionsbetrag: **€1.000–10.000** (oder höher)
      - Haltedauer: **Tage bis Wochen** (oder kürzer: Minuten bis Stunden)
    - **Trader** (`meetsTraderRiskClass5DerivativesExperienceCriteria`) — strengeres Profil:
      - Transaktionen: **50+**
      - Investitionsbetrag: **≥ €10.000**
      - Haltedauer: **Minuten bis Stunden**
    - **Investor-Sonderpfad zu RK 5** (zusätzlich zum Score 19–25): nicht arbeitslos (Step 15) + Investor-16c-Gate + Rendite ≥ 50 % (Step 17); siehe `RiskClassCalculationService.canInvestorGetRiskClass5`.
    - Visualisierung: `Documentation/diagrams/rc5-signup-flow-4seiten.pdf` (DE) / `rc5-signup-flow-4seiten-en.pdf` (EN) — Seiten 1–3 RK5, **Seite 4 Schritte 22–24 (Role Agreement)**.
    - **Server-Spiegelung:** `backend/parse-server/cloud/utils/riskClass5DerivativesGate.js` + Contract `contracts/riskClass5DerivativesGate.json` — einmalige Durchsetzung bei `completeOnboardingStep` (`risk`/`verification`), nicht pro Trade.
  - **Signup-Last (Skalierung):** `saveOnboardingProgress` — ein `OnboardingProgress`-Dokument pro Nutzer (Upsert), `_User.save` nur bei Schrittwechsel, Position-only überschreibt keine Blob-Daten, Rate-Limit ~40/min/Nutzer; iOS debounced partial saves (~400 ms); Finalize ohne doppeltes `risk`-Complete; Mongo-Indexes via Migration `onboarding_signup_indexes_v1`.
  - **Onboarding-Shell / Ressourcen (iOS, seit 2026-06):** Während `!onboardingCompleted` kein `MainTabView`, kein SLA-Polling, kein Retail-Background-Sync (siehe §3.2). Telemetrie `onboarding_started` beim Verlassen von Welcome (`persistStepTransition`); Default-Rolle in `SignUpData` bleibt `.investor`. Kontoauszug-Fetch (`TraderAccountStatementBuilder`): leere Server-Timeline bei neuem Konto **ohne** Fehler-Log (nur bei echtem API-Fehler warnen).
  - **Step 17 (Gewinnziel, Verlusttragfähigkeit & Wissenstest):**
    - **UI-Reihenfolge:** Gewinnziel → Verlusttragfähigkeit & Risikobereitschaft → Wissenstest; Screen scrollt beim Step-Wechsel nach oben.
    - Nutzer muss **alle** Wissenstest-Fragen beantworten und **Ja/Nein** zum Totalverlustrisiko wählen, um weiterzugehen.
    - **Falsche Quiz-Antworten blockieren nicht** — stattdessen Lernhinweis + Link zur In-App-Lernseite (`LeveragedProductsLearningView`).
    - **Risikoklasse 1 (konservativ)** wird in der Zusammenfassung erzwungen, wenn `leveragedProductsTotalLossRiskAcknowledged == false` **oder** der Wissenstest beantwortet, aber nicht bestanden ist (`requiresConservativeRiskClassFromOnboarding` in `SignUpData`).
    - iOS- und Backend-Fragenversion müssen übereinstimmen (aktuell **1.2**); Fragen/Optionen nur koordiniert in beiden SSOT-Dateien ändern.
  - **Step 22 (Hinweis Risikoklassifizierung):**
    - RK **1–4** → zurück zur Landing Page (wenn `shouldReturnToLandingAtRiskNote`).
    - RK **5–6** → Landing nur, wenn der Nutzer die Risikoklasse **nicht** manuell erhöht hat (`shouldReturnToLandingAtRiskNote`).
    - RK **7** → Onboarding fortsetzen → Schritt 23.
  - **Step 23 (RK7-Bestätigung):** Hochrisiko-Warnung; Button **„Weiter zur Vereinbarung“** → Schritt 24 (kein direktes Finalize mehr).
  - **Step 24 (Role Agreement — Legal Gate 2):** rollenspezifische Trader-/Investor-Vereinbarung (`getCurrentLegalDocument` → `trader_agreement`/`investor_agreement`, Fallback `RoleAgreementBundledContent`); `ScrollToAcceptReader` (Scroll-to-end, feste Höhe ~360 pt, Parent-Scroll disabled); Checkbox; `RoleAgreementConsentService` → `recordRoleAgreementConsent`; Button **„Zustimmen und Registrierung abschließen“** → `finalizeRegistration` (`mergedUserForFinalRegistration` behält Parse-`objectId` → `updateProfile` Cloud Function → `completeOnboardingStep` legalConsent + verification → `refreshUserData` → `applyOnboardingCompletion` → Device-Store-Mirror) → Dashboard via `UserSessionObserver`/`onboardingCompleted` (kein Downgrade nach Server-Refresh).
  - **Server bleibt maßgeblich** für Joi-Validierung und `OnboardingAudit`-Snapshot beim Schritt `risk` (siehe `onboarding.js`); **Produkt-Guard** `productAccessGate` erzwingt Rollenvereinbarung vor Trading/Investing.
- **Minimal-Checks**
  - Step Navigation funktioniert (vor/zurück, Progress).
  - Validation Errors werden korrekt angezeigt (kein “silent fail”).
  - Contact: ohne beide Legal-Toggles kein „Konto anlegen“.
  - Welcome nach Kontoanlage: Investor/Trader-Picker disabled; Resume zeigt Server-Rolle (nicht Blob-`userRole`).
  - Step 16: `none` → keine €-/Zeit-Follow-ups; Step-Wechsel startet oben.
  - Step 16c: Investor-Gate (1–10 / €1k–10k / Tage–Wochen+) vs. Trader-Gate (50+ / ≥€10k / Minuten–Stunden); ohne Gate max. RK 4 trotz Score.
  - Step 17: UI-Reihenfolge Gewinnziel → Verlusttragfähigkeit → Wissenstest; Nein bei Totalverlust → Summary zeigt RK1; falscher Quiz → RK1, Weiter trotzdem möglich.
  - Step 22: Landing-Routing für RK1–6 wie oben; RK7 → Schritt 23.
  - Step 23–24: Role Agreement nur nach RK7-Pfad; Scroll-Gate + Checkbox vor Abschluss; ohne Scroll kein aktiver Abschluss-Button.
  - Step 24 Finalize: nach Erfolg `onboardingCompleted=true`, Wechsel zu `MainTabView` (kein blauer Placeholder-Loop).
  - Trading/Investing ohne Rollenvereinbarung: serverseitig `OPERATION_FORBIDDEN` (`productAccessGate`).
  - Nach frischer Registrierung: kein redundantes Legal-Modal auf demselben Install.
  - Während Onboarding: kein `MainTabView appeared` in Logs; kein SLA-/Ticket-Fetch für Retail.

### 3.4 Investing (Investor Discovery → Investment → Portfolio)

- **Entry Points**
  - Discovery/Portfolio: `FIN1/Features/Investor/Views/*` und `ViewModels/*`
  - Investment Erstellung: `FIN1/Features/Investor/Views/InvestmentSheet.swift` + `InvestmentSheetViewModel`
  - Service Layer: `FIN1/Features/Investor/Services/*` (`InvestmentService`, Creation/Completion Services)
- **Protected Behaviors**
  - Investment-Erstellung arbeitet über Service Layer (`InvestmentService.createInvestment(...)`), nicht inline im ViewModel.
  - **App Service Charge** (Investor-only) bleibt korrekt:
    - Berechnung im UI/VM: `CalculationConstants.ServiceCharges.appServiceChargeRate` (siehe `InvestmentSheetViewModel.appServiceCharge`).
    - Validation darf nicht nur “Investment Amount” prüfen, sondern **Investment + Service Charge** (siehe `totalRequiredAmount`/`hasSufficientCashBalance`).
  - Pool-Logik bleibt konsistent (keine Formel-Drift; siehe `1.1 Financial Calculations & Accounting Guardrails`).
  - Collection Bill/Investment Statements bleiben **authoritativ** via `InvestorCollectionBillCalculationService` (kein Re-Implementieren in UI/VM).
- **Backend Contracts (wenn Parse aktiv)**
  - Cloud Functions wie `createInvestment`, `getInvestorPortfolio` dürfen nicht ohne Migration geändert werden.
- **Minimal-Checks**
  - InvestmentSheet: createInvestment Flow funktioniert (inkl. Error States).
  - Service Charge wird korrekt angezeigt und in Cash-Reserve-Check berücksichtigt.
  - Portfolio/Discovery Rendering & Filter/Watchlist unverändert nutzbar.

### 3.5 Trading (Trader Orders/Trades/Depot)

- **Entry Points**
  - Orders: `FIN1/Features/Trader/Views/BuyOrderView.swift`, `SellOrderView.swift`
  - ViewModels: `FIN1/Features/Trader/ViewModels/*Order*ViewModel.swift`
  - Placement/Validation: `FIN1/Features/Trader/Services/BuyOrderPlacementService.swift` + Validator Pattern
- **Protected Behaviors**
  - **Pre-trade Checks** werden nicht umgangen:
    - Extend/verwende `BuyOrderValidator` Pattern (Compliance Rule).
  - **Paired-Buy-Schutz:** Kein Trader-only-Buy, wenn reserviertes Pool-Kapital serverseitig/lokal existiert (`TraderPairedBuyPlacementGuard`; Backend-Refresh vor Kauf in `BuyOrderPlacementService` / `BuyOrderViewModel`).
  - **Pool-UX (Investor-Schutz):** Kein globales „Pool active“ im Dashboard; Status nur **pro Depot-Position** nach Mirror-Aktivierung (`DepotPositionPoolStatusResolver` / Kachel „Investment-Pool“). Reserviert (RSV) ≠ `active`.
  - **Audit Logging** bei Trading-Aktionen darf nicht “aus Versehen” entfernt werden (MiFID/Compliance).
  - Status-/Lifecycle Logik bleibt konsistent (Orders/Trades/Invoices/Notifications).
  - **Profit/ROI/Tax/Fee Displays bleiben konsistent** (siehe `1.1`):
    - Profit Display Contract: `Trade.displayProfit` (Fallback Chain nicht ändern).
    - Tax-Breakdown nutzt `InvoiceTaxCalculator`.
    - Fee-Breakdown nutzt `FeeCalculationService` + `CalculationConstants`.
- **Backend Contracts**
  - Cloud Functions `placeOrder`, `calculateOrderPreview`, `getOpenTrades` sind stabile Contracts.
- **Minimal-Checks**
  - Buy/Sell Order UI: placeOrder triggert erwartete UI-Updates (Loading, Validation, Error).
  - Depot/Trades Overview: Live Updates (LiveQuery) degrade gracefully, wenn Server nicht erreichbar.
  - Trades Overview vs Detail vs Steuer/Breakdown: identische Zahlen (keine Abweichung zwischen Screens).

### 3.6 Notifications & Documents (Cross-User-Safety kritisch)

- **Entry Point**
  - `FIN1/Shared/Components/DataDisplay/NotificationsView.swift`
  - `FIN1/Shared/ViewModels/NotificationsViewModel.swift`
- **Wie es funktioniert**
  - Kombiniert Notifications + Documents in einer UI-Liste.
  - Filter ist rollenbasiert initialisiert.
  - “Smart Cleanup”: gelesene **Notifications** (nicht der Tab **Documents**) verschwinden nach 24h aus der Hauptliste → Archiv.
  - Buchungsbelege: SSOT `getUserDocumentInbox` (ein CF); `DocumentService.refreshUserDocumentInbox` mit TTL + `userDocumentInboxShouldRefresh` nach Settlement/Investment.
- **Protected Behaviors (Security/Privacy)**
  - **Muss immer nach aktuellem User scopen** (`ledgerUserIdCandidates` + legacy `user:email`):
    - Notifications: `notification.userId` in erlaubten Keys
    - Documents: alle Cache-Zeilen mit passendem `document.userId` (nicht nur ein einzelner Key)
  - “Mark All Read” darf nur die eigenen Notifications betreffen.
  - UI darf keine fremden Dokumente/Notifications anzeigen (Regression-High-Risk).
- **Minimal-Checks**
  - Wechsel zwischen Test-Usern: keine Notifications “leaken”.
  - Trader nach abgeschlossenem Trade: Tab **Documents** zeigt Collection Bill **und** Gutschrift (wenn Provision > 0).
  - Investor: Tab **Documents** zeigt `investorCollectionBill` für abgeschlossene Pool-Trades.
  - Archiv/24h-Logik gilt für Notifications; Documents-Tab bleibt für Belege sichtbar.

### 3.7 FAQs (server-driven + caching + placeholder replacement)

- **Entry Points**
  - Service: `FIN1/Shared/Services/FAQContentService.swift`
  - Landing FAQ UI: `FIN1/Features/Authentication/Views/Components/LandingFAQView.swift`
  - Help Center UI: Profile/Help Center Views (Shared/Profile Components)
- **Backend Contract**
  - Cloud Functions:
    - `getFAQCategories(location: "landing"|"help_center"|"csr")`
    - `getFAQs(isPublic: true, categorySlug?: ...)`
- **Protected Behaviors**
  - Location-Gating:
    - Landing zeigt nur Kategorien, die für landing freigeschaltet sind.
    - Help Center zeigt nur Kategorien, die für help_center freigeschaltet sind.
  - Caching:
    - Cached Categories/FAQs werden per UserDefaults key gespeichert und TTL-basiert genutzt.
    - Keys sind Contract (bei Änderung Cache-Migration beachten).
  - Placeholder Replacement bleibt erhalten:
    - z.B. `{{APP_NAME}}` wird durch `AppBrand.appName` ersetzt.
- **Minimal-Checks**
  - Ohne ParseAPIClient: UI zeigt sinnvolles Fallback/Fehler (kein Crash).
  - Mit ParseAPIClient: Kategorien/FAQs werden geladen, sortiert, gefiltert.

### 3.8 Profile (Settings, Legal, Notifications Settings, Risk Profile)

- **Entry Points**
  - Profile UI: `FIN1/Shared/Components/Profile/**`
  - Legal Modals: `TermsOfServiceView`, `PrivacyPolicyView`, `ImprintView` (über `TermsContentService`)
  - Notification Settings: `NotificationsSettingsView`
- **Protected Behaviors**
  - Legal Views dürfen nicht “statisch” werden, wenn server-driven aktiv ist.
  - Profile darf keine sensitiven Daten leaken (Token/Secrets).
  - Risk Profile Änderungen müssen konsistent mit RiskClass/Experience Services bleiben.
- **Minimal-Checks**
  - Öffnen aller Profile Modals (Terms/Privacy/Imprint, Notification Settings).

### 3.9 CSR (Customer Support: Tickets, SLA, Audit, 4-Augen)

- **Entry Points**
  - `FIN1/Features/CustomerSupport/`
  - Audit Logging: `FIN1/Features/CustomerSupport/Services/AuditLoggingService.swift`
- **Protected Behaviors**
  - **Audit Logging** ist Pflicht für CSR-relevante Datenzugriffe/Änderungen.
  - SLA Monitoring darf nicht “still” entfernt werden (Support-Prozess).
  - 4-Augen-Prinzip (Approval Queue) darf nicht umgangen werden.
- **Minimal-Checks**
  - CSR Dashboard lädt, Ticket Detail Views funktionieren.
  - Audit Logs werden bei Aktionen erzeugt (mindestens auf Service-Ebene sichtbar).

### 3.10 Legal / Terms Acceptance (server-driven, auditierbar)

- **Entry Points**
  - Post-Login Device-Gate: `AuthenticationView` + `TermsAcceptanceModalView`
  - Sign-up Gate 1: `SignUpLegalConsentSection` (Contact)
  - Services: `TermsContentService`, `TermsAcceptanceService`, `DeviceLegalConsentStore`
  - Backend: `recordLegalConsent`, `getDeviceLegalConsentAcknowledgements`, `persistOnboardingLegalConsents`, `productAccessGate`
- **Protected Behaviors**
  - **Konto vs. Install:** Profil-Flags (`acceptedTerms`, `acceptedPrivacyPolicy`) und `LegalConsent` mit `source: onboarding` allein reichen nicht — Device-Gate verlangt lokales Ack oder `recordLegalConsent` mit `source: app` pro aktiver Version.
  - Version-Auflösung: Cache → Server → Profil → Bundled Fallback (`LegalConsentVersionResolver`).
  - Logging (Delivery/Consent) darf nicht entfernt werden, wenn Parse aktiv ist.
  - Kein „silent accept“: Modal erfordert explizite Accept-Buttons; kein Auto-Dismiss bei nur einem Dokument.
  - Server: `assertProductAccessEligible` blockiert Trading/Investment ohne abgeschlossenes Onboarding und beide Konto-Consents.
  - Kanonische Detail-Doku: `Documentation/LEGAL_DOCS_AUDIT_TRAIL.md`.

### 3.11 Accounting Documents: Invoices, Collection Bills, Account Statements (Monthly)

- **Zweck**
  - Dieses Feature bündelt **revisionsrelevante** Dokumente: Rechnungen/Gutschriften, Collection Bills, Kontoauszüge (inkl. Monatsdokumente).
  - Änderungen hier sind High-Risk, weil sie **Zahlen**, **Dokumentnamen** und **Ledger-Logik** betreffen.

- **Entry Points (Code)**
  - Invoices (Service): `FIN1/Features/Trader/Services/InvoiceService.swift`
  - Invoice Calculations Helpers: `FIN1/Shared/Extensions/Invoice+Calculations.swift`
  - Account Statements:
    - Investor Snapshot: `FIN1/Shared/Accounting/InvestorAccountStatementBuilder.swift`
    - Trader Snapshot: `FIN1/Shared/Accounting/TraderAccountStatementBuilder.swift`
  - Monthly Statement Creation: `FIN1/Shared/Services/MonthlyAccountStatementGenerator.swift`
  - Monthly Statement **Trigger** (Lifecycle): `MonthlyStatementPrefetch` in `FIN1/FIN1App.swift` — siehe `Documentation/AccountStatementsAndReports.md`.

- **Protected Behaviors**
  - Monatsdokumente werden nur für **abgeschlossene Monate** erzeugt (current month wird übersprungen).
  - Keine Duplikate (existierende Docs werden erkannt).
  - Opening/Closing/Running Balances werden ausschließlich über Snapshot-Builder bestimmt.
  - Profit/Tax/Fee Berechnungen, die in Dokumente einfließen, folgen `1.1` (keine Neben-Implementationen).

- **Minimal-Checks**
  - Account Statement Screen: Snapshot wirkt plausibel, Running Balance stimmt bei Sortierung/Filterung.
  - Monthly Generator: erzeugt keine Statements für den aktuellen Monat, erstellt nichts doppelt, und erzeugt eine Notification.

## 4) Change-Checkliste (für PRs)

Wenn du ein Feature anfasst:

- **Scope**: Welche Feature-Sektion betrifft es? (oben referenzieren)
- **Protected Behaviors**: bleiben sie erfüllt?
- **Contracts**: Cloud Function Names / NotificationCenter Names / Public Models nicht gebrochen?
- **Security/Privacy**: kein Cross-User Leak, keine Secrets in Logs?
- **Tests/Smoke**: mind. die Minimal-Checks manuell verifizieren, plus relevante Unit/UI Tests.

