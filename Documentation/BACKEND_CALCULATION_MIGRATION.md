# Backend-Authoritative Financial Calculations — Migration Plan

## Status: Phase 1 COMPLETE — Phase 2 COMPLETE — Phase 3 COMPLETE

## Problem

Financial calculations (commission, profit distribution, account statement booking, document generation) currently happen in **both** backend (Parse Cloud Code) and frontend (Swift services). This causes:

- **Data drift**: Backend and frontend can calculate different values (root cause of the 10% vs 30% commission bug)
- **No atomicity**: Frontend async operations can fail mid-way, leaving half-booked entries
- **Compliance risk (GoB, MiFID II)**: Client-side calculations are not tamper-proof or auditable
- **Multi-client inconsistency**: iOS app and Admin Portal may see different values

## Target Architecture

```
Backend (Parse Cloud Functions)         Frontend (iOS App)
─────────────────────────────           ─────────────────────
Trade.afterSave:                        Reads and displays:
  → Calculate commission                  → AccountStatement entries
  → Book AccountStatement (trader)        → Commission records
  → Book AccountStatement (investor)      → Credit Notes / Collection Bills
  → Create Credit Note record             → Settlement summaries
  → Create Collection Bill record
  → Create Commission record             Estimates/Previews (labelled):
  → Send notifications                    → Live profit preview
  → Return settlement result              → Estimated commission
```

## Current State Analysis

### Backend ALREADY does (trade.js, investment.js, order.js):
- ✅ Commission rate from Configuration class (`cloud/utils/configHelper`)
- ✅ Gross profit / commission / net profit calculation (trade.js beforeSave)
- ✅ Profit distribution to investors (trade.js afterSave → distributeTradeProfit)
- ✅ PoolTradeParticipation settlement (profitShare, commissionAmount, etc.)
- ✅ Investment value updates (currentValue, profit, totalCommissionPaid)
- ✅ Commission record creation
- ✅ Investor notifications
- ✅ Kontobuchungen für Investment-Lifecycle (Feature Wallet deaktiviert; Nutzer hat normales Konto)
- ✅ Order invoice creation
- ✅ Audit logging

### Backend NOW does (Phase 1 — completed 2026-03-01, refactor update 2026-03-19):
- ✅ **AccountStatement entries** — `utils/accountingHelper.js:bookAccountStatementEntry()` creates trader commission credit and investor debit/credit entries
- ✅ **Credit Note document** — `utils/accountingHelper.js:createCreditNoteDocument()` creates trader commission documents
- ✅ **Collection Bill document** — `utils/accountingHelper.js:createCollectionBillDocument()` creates investor per-trade statements
- ✅ **Idempotent settlement** — `utils/accountingHelper.js:settleCompletedTrade()` checks for existing entries before re-booking
- ✅ **Modularized helper internals** — moved to `utils/accountingHelper/` (`statements.js`, `documents.js`, `legs.js`, `settlement.js`, `shared.js`) with `accountingHelper.js` as compatibility loader
- ✅ **Cloud Functions** — `getTradeSettlement` and `getAccountStatement` defined in `functions/trading.js` (require real Parse auth — see Phase 2 prerequisites)
- ✅ **Parse schemas** — `AccountStatement`, `Document`, `WalletTransaction` classes with indexes created

### Phase 2 progress (2026-03-01):
- ✅ **Real Parse user authentication** — `UserService.signIn()` calls Parse REST `/login`, gets real session tokens; `ParseAPIClient` passes `r:` tokens through (no longer filtered); fallback to local auth if backend unavailable
- ✅ **stableId mapping** — Parse `_User` records have `stableId` field matching frontend `user:email` format; cloud functions use `getUserStableId()` helper to resolve
- ✅ **Frontend reads backend AccountStatement (Trader)** — `TraderAccountStatementBuilder.buildSnapshotWithWallet` accepts `SettlementAPIService`, uses backend commission entries when available, falls back to local credit notes
- ✅ **Frontend reads backend AccountStatement (Investor)** — `InvestorAccountStatementBuilder.buildSnapshotWithWallet` accepts `SettlementAPIService`, fetches backend `commission_debit` and `investment_profit` entries, falls back to local `InvestorCashBalanceService` ledger
  - *(Methodenname „buildSnapshotWithWallet“ bleibt; Konto-Feature ist deaktiviert, Nutzer hat normales Konto.)*
- ✅ **Cloud functions verified** — `getAccountStatement` and `getTradeSettlement` return correct data with real session tokens
- ✅ **TransactionLimitService thread safety** — Removed Parse Server dependency (classes don't exist), added `NSLock` for dictionary access to prevent data races from concurrent calls

### Remaining (future hardening):
- ⬜ **InvoiceFactory** → replace local generation with backend `Invoice` reads (low priority; `InvoiceAPIService.fetchInvoices` already prefers cloud function)
- ⬜ **TradingNotificationService** → consider backend push notifications instead of local document generation
- ⬜ **Feature flags** → implement `frontend_readonly_mode` flag to disable fallback paths in production

### Frontend service roles (after Phase 3):
- **ProfitDistributionService** → reads backend settlement, local fallback labelled
- **CommissionCalculationService** → async methods read backend entries, pure arithmetic for display
- **InvestmentCashDistributor** → reads backend AccountStatement, local fallback labelled
- **OrderLifecycleCoordinator** → credit note: reads backend settlement first
- **TraderCashBalanceService** → local UI bookkeeping only (balance display)
- **InvestorCashBalanceService** → local UI bookkeeping only (balance display)
- **InvoiceAPIService** → prefers `getUserInvoices` cloud function, falls back to direct query

---

## Migration Phases

### Phase 1: Backend as Authority for Trade Settlement — COMPLETE

**Goal**: When a trade completes, the backend creates ALL financial records. Frontend reads them.

**Completed 2026-03-01 (+ refactor deployed 2026-03-19)**:
- `utils/accountingHelper.js` deployed to Parse Server with `bookAccountStatementEntry`, `createCreditNoteDocument`, `createCollectionBillDocument`, `settleCompletedTrade`
- Internal split deployed: `utils/accountingHelper/{statements,documents,legs,settlement,shared}.js`
- `trade.js` `afterSave` trigger calls `settleCompletedTrade()` on trade completion
- `trading.js` exposes `getTradeSettlement` and `getAccountStatement` cloud functions
- Parse schemas created: `AccountStatement` (with `userId_createdAt` and `tradeId_source` indexes), `Document`, `WalletTransaction`
- All 19 existing completed trades back-settled successfully (18 AccountStatement entries, 17 CreditNotes)
- Frontend continues to work with local data (unchanged); backend records are the authoritative ledger
- Frontend diagnostic logging from previous debugging cleaned up

#### 1a. AccountStatement class (new)

Create `AccountStatement` entries in the backend when a trade is settled:

```javascript
// Trader gets commission credit
AccountStatement {
  userId: traderId,
  entryType: 'commission_credit',
  amount: totalCommission,       // positive = credit
  tradeId: trade.id,
  tradeNumber: trade.tradeNumber,
  description: 'Commission for Trade #XXX',
  balanceBefore: ...,
  balanceAfter: ...,
  createdAt: Date
}

// Investor gets profit credit (per participation)
AccountStatement {
  userId: investorId,
  entryType: 'investment_profit',
  amount: netProfit,             // positive = credit
  investmentId: investment.id,
  tradeId: trade.id,
  description: 'Profit from Trade #XXX',
  ...
}

// Investor commission debit (per participation)
AccountStatement {
  userId: investorId,
  entryType: 'commission_debit',
  amount: -commission,           // negative = debit
  investmentId: investment.id,
  tradeId: trade.id,
  description: 'Commission for Trade #XXX',
  ...
}
```

#### 1b. Document records (Credit Note, Collection Bill)

Create `Document` records in the backend:

```javascript
// Trader Credit Note
Document {
  userId: traderId,
  type: 'trader_credit_note',
  name: 'CreditNote_Trade{N}_{date}_{hash}.pdf',
  tradeId: trade.id,
  accountingDocumentNumber: 'CN-YYYY-NNNNNNN',
  metadata: {
    commissionAmount, commissionRate, grossProfit, netProfit,
    investorBreakdown: [{ investorId, grossProfit, commission }]
  }
}

// Investor Collection Bill (per investment)
Document {
  userId: investorId,
  type: 'investor_collection_bill',
  name: 'CollectionBill_Investment{ID}_{date}_{hash}.pdf',
  investmentId: investment.id,
  tradeId: trade.id,
  accountingDocumentNumber: 'CB-YYYY-NNNNNNN',
  metadata: {
    ownershipPercentage, grossProfit, commission, netProfit,
    feeBreakdown: { orderFee, exchangeFee, foreignCosts }
  }
}
```

#### 1c. Cloud Function: getTradeSettlement

Frontend calls this to get the authoritative settlement data for display:

```javascript
Parse.Cloud.define('getTradeSettlement', async (request) => {
  const { tradeId } = request.params;
  // Returns: commission, netProfit, accountStatementEntries, documents
});
```

#### Frontend state (Phase 1):

- Frontend local booking (via `ProfitDistributionService`, `OrderLifecycleCoordinator`) continues to run alongside backend settlement for UI consistency
- `TraderAccountStatementBuilder` gracefully handles Konto-API-Failures (no statement wipe)
- `AccountStatementViewModel` observes `.invoiceDidChange` for immediate credit note display
- Commission entries display in correct chronological order (after trade settlement entries)
- `SettlementAPIService` exists but cloud function calls require real Parse auth (Phase 2)

#### Phase 2 prerequisites: DONE

- ✅ **Real Parse authentication**: `UserService.signIn()` calls Parse REST `/login`; real `r:` tokens used for cloud function calls
- ✅ **Frontend reads from backend**: `TraderAccountStatementBuilder` fetches backend `AccountStatement` entries via `SettlementAPIService.fetchAccountStatement()` and uses them for commission data; falls back to local credit notes if backend unavailable

### Phase 2: Real Auth + Backend Document Generation — COMPLETE

**Goal**: Real Parse authentication + backend generates document metadata with all line items.

**Completed 2026-03-01**:
- Real Parse login in `UserService.signIn()` via REST API (`ParseAPIClient.login()`)
- `ParseAPIClient.sessionToken` no longer filters `r:` tokens — real session tokens pass through
- Fallback session tokens use `sim:` prefix (for offline/no-backend scenarios)
- All Parse `_User` records have `stableId` field (`user:email`); seeded/mock test users use the password from `TestUserConstants.swift` / `seedTestUsers` (not duplicated in Markdown docs)
- Cloud functions in `trading.js` use `getUserStableId(user)` helper for all data queries
- `TraderAccountStatementBuilder.buildSnapshotWithWallet` accepts optional `SettlementAPIServiceProtocol`; uses backend commission entries when available
- `AccountStatementViewModel` passes `settlementAPIService` to the builder

**Completed 2026-03-01 (backend invoice infrastructure)**:
- `order.js:createOrderInvoice()` now calculates full fee breakdown via `calculateOrderFees()` and stores `lineItems` array (securities, orderFee, exchangeFee, foreignCosts) and `feeBreakdown` object on each `Invoice` record
- Cloud functions `getTradeInvoices(tradeId)` and `getUserInvoices(limit, skip, invoiceType)` deployed in `trading.js`
- `settleCompletedTrade()` includes `orderFees` (buy/sell fee breakdown) in settlement summary

**Completed 2026-03-01 (frontend invoice integration)**:
- `SettlementAPIServiceProtocol` extended with `fetchTradeInvoices(tradeId:)` and `fetchUserInvoices(limit:skip:invoiceType:)`
- `BackendInvoice`, `BackendInvoiceLineItem`, `BackendFeeBreakdown`, `BackendInvoiceListResponse` response models added
- `BackendInvoice.toLocalInvoice()` converter maps backend `lineItems` (securities, orderFee, exchangeFee, foreignCosts) to local `InvoiceItem` models with correct `InvoiceItemType`
- `InvoiceAPIService.fetchInvoices()` now calls `getUserInvoices` cloud function first (session-based, resolves stableId), falls back to direct Parse query
- `InvoiceService.loadInvoices()` merges backend invoices with local-only invoices to prevent duplicates

**Erweiterung 2026-05-07 — `getUserInvoices` / `getTradeInvoices` für Investoren (Settlement-Rechnungen sichtbar):**

- **Hintergrund:** `order.js` → `createOrderInvoice()` setzt auf der Parse-Klasse `Invoice` das Feld **`userId` = `order.traderId`** (Trader-Stable-ID). Rein equality-basierte Abfragen `Invoice.userId == getUserStableId(currentUser)` liefern für **Investor-Sessions** daher **keine** Kauf-/Verkaufs-Rechnungen (`buy_invoice` / `sell_invoice`), obwohl PDF/`Document`-Zeilen für den Investor existieren können.
- **Cloud:** In `functions/trading.js`:
  - Hilfsfunktion **`getTradeIdsForInvestorStableId(stableId)`**: Investments mit `investorId == stableId` → zugehörige `tradeId`s aus **`PoolTradeParticipation`**.
  - **`getUserInvoices`**: für `role === 'investor'` **`Parse.Query.or`**: (a) bestehende Eigene (`userId == stableId`, z. B. Service Charge), **plus** (b) Invoices mit **`tradeId ∈ tradeIds`** und **`invoiceType` ∈** `buy_invoice` / `sell_invoice` / `buy` / `sell`.
  - **`getTradeInvoices`**: Investoren dürfen nur Trades laden, an denen sie teilnehmen (Teilnahme-Check); ohne `equalTo('userId', stableId)`, da Zeilen weiterhin den Trader als `userId` tragen.
- **Frontend:** Hydration/Zuordnung `Document` ↔ `Invoice` weiterhin wie implementiert (`InvoiceService.invoice(matching:)`, laden über `loadInvoices`); die Cloud-Erweiterung behebt „0 Invoices vom Backend für Investor“ ohne falsche Datenmodell-Doppelungen.

**Paired Buy / Mirror-Trade-Leg (Cloud Code — ergänzend zu Mirror-*Basis* für Belege):**

Zwei Themen nicht verwechseln:

1. **Mirror-Basis / buyLeg–sellLeg / Return-SSOT** (Berechnung für Collection Bills, Kontoauszug, `deriveMirrorTradeBasis`): gebündelt in **`Documentation/RETURN_CALCULATION_SCHEMAS.md`**, **`Documentation/ADR-009-iOS-Reads-Server-BuyLeg-SellLeg.md`**, `utils/accountingHelper/legs.js`, Tests `legs.mirrorBasis.test.js`.
2. **Paired execution: Trader-Leg ↔ Spiegel-Trade synchron halten** (Orders mit `pairExecutionId`, Pool-/Mirror-Trade-Objekt wird mitgeschrieben):
   - **`utils/pairedTradeMirrorSync.js`**: `syncMirrorTradeWhenTraderLegCompletes(traderTrade)` — findet Mirror-Buy-Order per `pairExecutionId`, übernimmt u. a. Sell-Seite / Kennzahlen auf den Mirror-`Trade`, setzt bei Vollständigkeit `completed`.
   - **`triggers/trade.js`**: ruft die Sync-Funktion nach relevanten Saves auf; wenn der Trade **in demselben Save** von partial auf **`completed`** springt, wird der **Partial-Sell-Delta-Pfad** übersprungen, damit nicht parallele/abweichende Abrechnungsstände zu **`settleAndDistribute`** entstehen (Kommentar im Trigger).
   - **`utils/accountingHelper/settlement.js`**: **`isPairedTraderLegTrade(trade)`** (Import aus `pairedTradeMirrorSync`) steuert u. a. **`skipPoolFallback`**, damit Settlement bei Paired-/Mirror-Kontext nicht mit inkonsistenten Pool-Fallback-Pfaden kollidiert.

3. **Server-Orchestrierung — Cloud Function `executePairedBuy`** (`functions/trading.js`, nur Rolle **trader**):
   - **Atomarer Vertrag:** neue Zeile **`PairedExecution`**, zwei persistierte Buy-**`Order`**-Beine (`legType` **`TRADER`** vs **`MIRROR_POOL`**, gemeinsames `pairExecutionId`, `clientOrderIntentId` zur **Idempotenz** / Retry).
   - **`saveAll`** beider Beine oder **Abbruch:** bei Fehler nach Teilerfolg werden angelegte Orders per **`destroyAll`** bereinigt, `PairedExecution` → `ABORTED` (best-effort Compensation).
   - **Nach durable commit (nicht rollbackbar):** **`finalizePairedBuyAfterCommit`** in **`utils/pairedBuyOrchestration.js`** — sortiert Beine (**TRADER vor MIRROR_POOL**), setzt jede Buy-Leg von `submitted` auf **`executed`** (Fees/`grossAmount`/`netAmount` via `calculateOrderFees`), sodass **`order.js` `afterSave`** läuft: **Trade + Invoice**; laut dortigem Kommentar: **Trader-Leg** ohne proportionale Pool-Allokation, **Pool nur auf der MIRROR_POOL-Leg**.
   - **`effectsApplied`** auf **`PairedExecution`** markiert erfolgreichen Abschluss (kein doppeltes Finalize); wiederholter Aufruf mit gleichem **`clientOrderIntentId`** kann Finalize nachholen (**idempotentReplay**).

Deploy: dieselbe Cloud-Ordnerstruktur; Änderungen wie üblich **rsync `cloud/` + `restart parse-server`**. (**Docker Compose** für die VM ist die **Infra-Orchestrierung** der Services; gemeint hier ist die **Geschäfts-Orchestrierung** Paired Buy im Parse Cloud Code.)

**Completed 2026-03-01 (collection bill read-only mapper)**:
- Backend `createCollectionBillDocument` enhanced: stores `buyLeg` and `sellLeg` detail in metadata (quantity, price, amount, fees breakdown, residualAmount)
- `settleCompletedTrade` computes per-investor buy/sell legs from trade order data and investment capital
- Cloud function `getInvestorCollectionBills(limit, skip, investmentId, tradeId)` deployed in `trading.js`
- `SettlementAPIServiceProtocol` extended with `fetchInvestorCollectionBills()`
- `BackendCollectionBill`, `BackendCollectionBillLeg`, `BackendCollectionBillMetadata`, `BackendCollectionBillResponse` models added
- `InvestorCollectionBillCalculationService.calculateCollectionBillWithBackend()` tries backend data first, falls back to local calculation
- `InvestorInvestmentStatementViewModel` accepts optional `settlementAPIService`, `refreshFromBackend()` async method fetches backend-authoritative data
- `CollectionBillDocumentViewModel` passes `settlementAPIService` from `AppServices`
- `InvestorInvestmentStatementView` calls `refreshFromBackend()` via `.task` modifier

**Phase 2 COMPLETE** — All items delivered.

### Phase 3: Frontend Becomes Read-Only — COMPLETE

**Goal**: Frontend calculation services prefer backend-authoritative data; local calculation retained only as labelled fallback.

**Completed 2026-02-27**:
- **`ProfitDistributionService`**: `distributeProfit()` now calls `fetchTradeSettlement()` first; if `isSettledByBackend` is true, reads `totalFees` and `netProfit` from the backend response and only performs local UI bookkeeping (trader cash balance credit, pool profit distribution, investment profit refresh). Local calculation extracted into `distributeLocalFallback()` and is only reached when backend is unavailable.
- **`CommissionCalculationService`**: Added optional `settlementAPIService` dependency (late-bound via `configure(settlementAPIService:)` in `AppServicesBuilder+Investment`). `calculateCommissionForInvestor()` and `calculateTotalCommissionForTrade()` now query backend `AccountStatement` `commission_debit` entries first; pure-arithmetic methods (`calculateCommission`, `calculateNetProfitAfterCommission`) remain unchanged (display/preview only).
- **`InvestmentCashDistributor`**: `distributeCash()` accepts optional `settlementAPIService`; `fetchBackendAmounts()` reads `sell_proceeds`/`profit_distribution`, `commission_debit`, and `residual_return` entries from backend `AccountStatement` for the investment. Local `InvestorInvestmentStatementAggregator` path is only reached when backend returns no data.
- **`InvestmentCompletionService`**: Receives `settlementAPIService` via DI and passes it to `InvestmentCashDistributor.distributeCash()`.
- **`OrderLifecycleCoordinator.generateCreditNoteIfCommissionExists()`**: Tries `fetchTradeSettlement()` first for authoritative commission/gross profit; falls back to local `InvestorGrossProfitService` + `CommissionCalculationService` if backend unavailable.
- **Wiring**: `AppServicesBuilder+Investment` passes `ctx.settlementAPIService` to `InvestmentCompletionService` and configures `CommissionCalculationService` with settlement API.

**Architecture after Phase 3**:
```
Backend (Parse Cloud Functions)         Frontend (iOS App)
─────────────────────────────           ─────────────────────
Source of truth:                        Primary path (online):
  AccountStatement entries                Read from backend APIs
  Document records                        Display authoritative data
  Invoice records
  Settlement summaries                  Fallback path (offline/error):
                                          Local estimation (labelled)
                                          Preserved for resilience
```

---

## Parse Classes (New/Modified)

| Class | Status | Purpose |
|-------|--------|---------|
| `AccountStatement` | ✅ Created | Trader/investor account entries (indexes: `userId_createdAt`, `tradeId_source`) |
| `Document` | ✅ Created | Accounting documents (Credit Notes, Collection Bills) from backend |
| *(Konto)* | *(Feature deaktiviert)* | Nutzer hat normales Konto; keine separate Wallet-UI. |
| `Commission` | Existing | Already created in trade.js |
| `PoolTradeParticipation` | Existing | Already settled in trade.js |
| `Trade` | Existing | No changes needed |
| `Investment` | Existing | Already updated in trade.js |

## Rollback Strategy

Each phase has a feature flag:
- `backend_account_statements_enabled` (Phase 1)
- `backend_document_generation_enabled` (Phase 2)
- `frontend_readonly_mode` (Phase 3)

Frontend checks these flags. If disabled, falls back to current client-side logic.

## Testing Strategy

1. Backend: Unit tests for each Cloud Function
2. Integration: Create a trade, verify all records are created atomically
3. Frontend: Verify data reads match backend records
4. Regression: Existing commission/profit values match after migration
