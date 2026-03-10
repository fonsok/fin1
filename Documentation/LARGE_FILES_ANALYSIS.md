# Analyse: Zu große Script-/Code-Dateien (Backend & FIN1 App)

**Stand:** 2026-02-26
**Kontext:** Cursor Rules (architecture.md) – File Size Limits: Models ≤200, Views ≤300, ViewModels/Services ≤400, Protocols ≤100.

---

## 1. Backend (Parse Cloud Code, Node.js)

### Kritisch (> 800 Zeilen)

| Datei | Zeilen | Empfehlung |
|-------|--------|------------|
| `backend/parse-server/cloud/functions/admin.js` | **~35** (Loader) | **Erledigt:** Aufgeteilt in `admin/` (helpers, dashboard, users, compliance, fourEyes, financial, security, permissions, userManagement, devHelpers, system, reports, onboarding). |
| `backend/parse-server/cloud/functions/seed.js` | **~17** (Loader) | **Erledigt:** Aufgeteilt in `seed/` (tickets, compliance, csrTemplates, faq, all, csrPermissions). |
| `backend/parse-server/cloud/functions/support.js` | **~17** (Loader) | **Erledigt:** Aufgeteilt in `support/` (customers, tickets, csrPermissions). |
| `backend/parse-server/cloud/functions/user.js` | **~18** (Loader) | **Erledigt:** Aufgeteilt in `user/` (verificationEmail, verificationPhone, profile, onboarding, faq, faqAdmin). |

### Moderat (500–800 Zeilen)

| Datei | Zeilen | Empfehlung |
|-------|--------|------------|
| `backend/parse-server/cloud/functions/templates.js` | 606 | Optional: Handlers in Untermodule. |
| `backend/parse-server/cloud/functions/configuration.js` | 566 | Überschaubar; bei Wachstum nach Lesen/Schreiben/Validierung trennen. |
| `backend/parse-server/cloud/utils/permissions.js` | 529 | Bei weiterem Wachstum: Rollen-Checks vs. Hilfsfunktionen trennen. |

**Vorteil Aufteilung Backend:** Bessere Wartbarkeit, kleinere Merge-Konflikte, klarere Verantwortlichkeiten, einfacheres Testen einzelner Bereiche. Kein negativer Runtime-Effekt (Node lädt Module einmal).

---

## 2. FIN1 iOS App (Swift)

### Cursor Rules – Limits

- **Services / ViewModels / Klassen:** max **400** Zeilen
- **Views:** max **300** Zeilen
- **Models:** max **200** Zeilen
- **Protocols:** max **100** Zeilen

### Deutlich über Limit (Services/ViewModels/Classes ≤400)

| Datei | Zeilen | Typ | Limit | Empfehlung |
|-------|--------|-----|-------|------------|
| `ParseAPIClient.swift` | **~249** (war 853) | Service | 400 | **Erledigt:** Protocol + Models in `ParseAPIClientProtocol.swift`; Implementierung in `+Fetch`, `+CRUD`, `+CloudFunctions`. |
| `SignUpCoordinator.swift` | **~305** (war 729) | Coordinator | 300 | **Erledigt:** Aufgeteilt in Extensions: +Verification (Email/Phone), +SessionTimeout, +Persistence, +StepDisplay; Hauptdatei unter 310 Zeilen. |
| `InvestorCashBalanceService.swift` | **566** | Service | 400 | Berechnungslogik in CalculationService; Sync/API in Extension. |
| `PriceAlertService.swift` | **563** | Service | 400 | Nach Verantwortung aufteilen (CRUD vs. Alerts-Logik vs. Sync). |
| `CustomerSupportService+Tickets.swift` | **548** | Service | 400 | Weitere Extension-Dateien pro Thema (Tickets, Templates, etc.). |
| `UserServiceProtocol.swift` | **520** | Protocol | 100 | Protocol auf Kern-API reduzieren; erweiterte APIs in `UserServiceProtocol+Extensions`. |
| `AppServicesBuilder.swift` | **~18** (war 463) | Builder | 400 | Erledigt: Orchestrierung in Hauptdatei; Build in +BuildContext, +Core, +Trader, +Investment, +Remaining. |
| `BuyOrderViewModel.swift` | **~256** (war 463) | ViewModel | 400 | **Erledigt:** Orchestrierung in Hauptdatei; Logik in +Types, +Bindings, +Investment, +TransactionLimits. |
| `InvoiceService.swift` | **~319** (war 470) | Service | 400 | **Erledigt:** PDF in `InvoicePDFService`; Backfill in `+CompletedTrades`, Validierung in `+Validation`; Kern-CRUD in Hauptdatei. |
| `OrderManagementService.swift` | **423** | Service | 400 | Nah am Limit; bei Erweiterung Lifecycle vs. API trennen. |

### Deutlich über Limit (Views ≤300)

| Datei | Zeilen | Limit | Empfehlung |
|-------|--------|-------|------------|
| `WalletView.swift` | **~139** (war 668) | 300 | **Erledigt:** Subviews in `Wallet/` (WalletBalanceCard, WalletQuickActionsSection, WalletRecentTransactionsSection, WalletDepositSheet, WalletWithdrawalSheet, WalletTransactionRow). |
| `CustomerDetailSheet.swift` | **~88** (war 567) | 300 | **Erledigt:** Sections in `CustomerDetail/` (Header, KYCSection, ContactSection, InvestmentsSection, TradesSection, DocumentsSection, TicketsSection, ActionsSection). |
| `FourEyesApprovalQueueView.swift` | **~66** (war 559) | 300 | **Erledigt:** Sections in `FourEyesApproval/` (StatsSection, FilterSection, RequestsSection, ApprovalRequestCard, ApprovalDetailSheet, HelperViews). |
| `CannedResponsePicker.swift` | **~275** (war 546) | 300 | **Erledigt:** Subviews in `CannedResponse/` (CategoryChip, CannedResponseCard, BackendTemplateCard, PickerSearchBar). |
| `PendingConfigurationChangesView.swift` | **~180** (war 526) | 300 | **Erledigt:** Subviews in `PendingConfiguration/` (ChangeDetails, ApprovalSheet, RejectionSheet, PendingChangeCard, PendingApprovalsNavigationLink). |
| `CustomerSupportDashboardView.swift` | **~281** (war 498) | 300 | **Erledigt:** QuickActions und RecentTickets in `CustomerSupportDashboard/` ausgelagert. |
| `BulkOperationsView.swift` | **~255** (war 491) | 300 | **Erledigt:** Subviews in `BulkOperations/` (BulkSelectableTicketRow, PriorityBadge, BulkActionButton, BulkAssignSheet, BulkCloseSheet). |
| `LandingView.swift` | **~73** (war 472) | 300 | Ausgelagert: `Landing/` (LandingOriginalStyleBody, LandingTypewriterStyleBody, LandingLegalLinksSection, FeatureRow, LandingConstants). |

### Content/Data-Dateien (optional prüfen)

- `PrivacyPolicyGermanContent.swift` (736), `PrivacyPolicyAmericanContent.swift` (716): Inhalt; wenn möglich aus externer Quelle (CMS/Remote) laden oder pro Abschnitt aufteilen.
- `TermsOfServiceGermanContent.swift` / `TermsOfServiceEnglishContent.swift` (je ~455): Ähnlich; eher Inhalt als „Code“ – Limits können flexibel gehandhabt werden, Aufteilung nach Kapiteln möglich.

### Models über 200 Zeilen

- `Investment.swift` (**~280**, war 457): **Erledigt.** Unterstützende Typen in `Investment+Types.swift` (InvestmentStatus, InvestmentTimePeriod, InvestmentPool, InvestmentReservationStatus, PoolStatus, InvestmentValidationError, InvestmentReservation, InvestmentAllocation, InvestmentSelectionStrategy).

---

## 3. Priorisierung (ressourcenschonend)

1. **Backend:** `admin.js` aufteilen – größter Brocken, klare Sektionen (Dashboard, Users, Compliance, FourEyes, Financial, Security, Reports, System).
2. **Backend:** `seed.js` und `support.js` – bei nächsten Touchen schrittweise in Domains/Stages aufteilen.
3. **FIN1:** `ParseAPIClient.swift` – zentral für alle Backend-Calls; Protocol + Models abtrennen, dann Implementation in Extensions.
4. **FIN1:** `SignUpCoordinator.swift` – wichtig für Onboarding; Schritt-/Verification-Logik auslagern.
5. **FIN1:** Große Views (WalletView, CustomerDetailSheet, …) – bei Änderungen Subviews extrahieren.

---

## 4. Umgesetzter Schritt (admin.js)

- **Erledigt:** `admin.js` wurde in Module unter `backend/parse-server/cloud/functions/admin/` aufgeteilt:
  - `helpers.js` – getRequesterIdString, getRoleDescription
  - `dashboard.js` – getAdminDashboard
  - `users.js` – searchUsers, getUserDetails, updateUserStatus
  - `compliance.js` – getComplianceEvents, reviewComplianceEvent, getAuditLogs
  - `fourEyes.js` – getPendingApprovals, withdrawRequest, approveRequest, rejectRequest
  - `financial.js` – getFinancialDashboard, getRoundingDifferences, createCorrectionRequest, getCorrectionRequests
  - `security.js` – getSecurityDashboard, getLoginHistory, terminateUserSession, forcePasswordReset
  - `permissions.js` – getMyPermissions, getAdminRoles
  - `userManagement.js` – getTestUserDetails, resetDevUserPassword, createTestUsers, createAdminUser, createCSRUser
  - `devHelpers.js` – getTradesWithInvestors, createTestPoolParticipations, initializeNewSchemas
  - `system.js` – getSystemHealth
  - `reports.js` – getSummaryReport, getBankContraLedger
  - `onboarding.js` – getOnboardingFunnel
- Die Datei `admin.js` ist nun ein schlanker Loader (~35 Zeilen); `main.js` bleibt unverändert mit `require('./functions/admin')`.

**Nächste Schritte:** Gleiches Muster für `seed.js` und `support.js` anwenden, wenn dort gearbeitet wird.
