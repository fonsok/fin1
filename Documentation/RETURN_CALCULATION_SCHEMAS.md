# Return Calculation Schemas — Trade & Investment (v1)

Status: **ACTIVE — authoritative across app, admin portal, customer support, and bills/invoices**
Owner: Backend/Accounting
Last reviewed: 2026-04-23
Related ADRs:
- `ADR-006-Server-Owned-Return-Percentage-Contract.md` — server-only SSOT for `metadata.returnPercentage`

---

## Scope & Principles

1. **Single Source of Truth (SSOT)**
   The backend computes all monetary values on the Investor Collection Bill (Buy Amount,
   Buy Fees, Net Sell Amount, Gross Profit, Commission, Net Profit, Residual Credit).
   The investor UI MUST show exactly the same numbers as printed on the bill.

   - `Gross Profit (€)`, `Commission (€)`, `Net Profit (€)`, `Total Buy Cost (€)` come
     from the bill's line items (populated by `InvestorInvestmentStatementAggregator`
     using the same inputs as the PDF generator).
   - `ROI1 (%)` and `ROI2 (%)` are derived **from these same bill numbers** so the
     table, the info sheet and the PDF always agree. They are NOT read from a separate
     `metadata.returnPercentage` field.
   - `metadata.returnPercentage` on the stored `investorCollectionBill` document is a
     denormalized ROI2 copy for analytics/reporting. It MUST equal the value derived
     from the bill's own line items; if drift is detected, the bill's line items are
     authoritative and the stored field is reconciled.

   Rationale: a stored ROI2 that disagrees with its own bill's numbers (as we observed
   during QA on 2026-04-20: bill showed Gross Profit 636,85 € / +65,69 % while
   `metadata.returnPercentage` stored 34,51 %) breaks investor trust. The bill is what
   the investor receives — it is the ground truth.

2. **Terminology & rates**
   The app uses exactly these labels across Investor / Admin / CSR UIs and bills/invoices:
   - `Gross Profit (€)` / `Gross Profit (%)` — pre-commission
   - `Commission (€)` — **trader commission** on investor gross profit (rate configured
     via admin panel, currently **11 %**, only charged when `Gross Profit > 0`)
   - `Net Profit (€)` — post-commission
   - `Return (€)` — monetary return (alias for Net Profit on investor side)
   - `Return (%)` — ROI2 (post-commission)
   - `ROI1 (%)` — classical ROI without commission (Gross Profit / Total Buy Cost)
   - `ROI2 (%)` — contractual ROI including commission (Net Profit / Total Buy Cost)

   The **App Service Charge** is a *separate* platform fee (currently **5 %** of the
   gross investment amount, configured via admin panel) and is NOT part of ROI1/ROI2.
   See §4.

3. **Consistency guarantee**
   The `Return (%)` in the "Completed Investments" table MUST equal the
   `Return (%)` derivable from the corresponding `InvestorCollectionBill`'s own line
   items (Gross Profit, Commission, Total Buy Cost). Both are ROI2.

4. **App Service Charge (separate from trade settlement)**
   The App Service Charge is NOT part of the investment/trade profit calculation and
   does NOT reduce the investment amount before the pool split. It is billed as a
   **separate direct debit from the investor's cash-balance account** (see
   `AppServiceChargeInvoice`).  The Account feature is disabled (no crypto
   trading), so there is no wallet account to debit against.
   - Rate: **5 %** of the gross investment amount (configured via admin panel).
   - Plus **19 % VAT** where applicable.
   - Debited at investment-activation time (not at trade-settlement time).
   - If the investor's cash balance is insufficient to cover the service charge at
     activation time, the investment MUST NOT activate and the investor MUST be shown
     a clear error to top up first.
   - See ADR-007 (App-Service-Charge-Cash-Balance-Debit, TBD).

   The two rates are independent:
   - **11 %** Trader Commission — applied to investor's Gross Profit, paid out of the
     trade settlement (reduces `Net Profit`).
   - **5 %** App Service Charge — applied to the gross investment amount, paid up-front
     from the investor's cash balance, independent of trade outcome.

---

## a) Trade — Calculation Schema (Trader view)

| +/− | Step | Formula | Meaning |
|:-:|---|---|---|
| + | Buy Amount (€) | `buyQuantity × buyPrice` | Security purchase value |
| + | Buy Fees (€) | `orderFee + exchangeFee + foreignCosts` | Buy-side fees |
| ═══ | ═══ | ═══ | ═══ |
| **=** | **Total Buy Cost (€)** | `Buy Amount + Buy Fees` | **Invested Amount (Trade)** |
| ═══ | ═══ | ═══ | ═══ |
| + | Sell Amount (€) | `sellQuantity × sellPrice` | Security sale value |
| − | Sell Fees (€) | `orderFee + exchangeFee + foreignCosts` | Sell-side fees |
| ═══ | ═══ | ═══ | ═══ |
| **=** | **Net Sell Amount (€)** | `Sell Amount − Sell Fees` | Net sale proceeds |
| ═══ | ═══ | ═══ | ═══ |
| − | Total Buy Cost (€) | `Buy Amount + Buy Fees` | Buy side total |
| ═══ | ═══ | ═══ | ═══ |
| **=** | **Gross Profit (€)** | `Net Sell Amount − Total Buy Cost` | Trade result before commission & taxes |
| ═══ | ═══ | ═══ | ═══ |
| **=** | **ROI1 (%)** | `Gross Profit / Total Buy Cost × 100` | Classical ROI (without commission) |
| ═══ | ═══ | ═══ | ═══ |
| + | Commission (€) | `Gross Profit × commissionRate` (only when Gross Profit > 0) | Trader receives commission |
| ═══ | ═══ | ═══ | ═══ |
| **=** | **Net Profit (€) (Trader)** | `Gross Profit + Commission` | Trade result incl. commission (trader side) |
| ═══ | ═══ | ═══ | ═══ |
| **=** | **ROI2 (%) (Trader)** | `Net Profit / Total Buy Cost × 100` | ROI incl. commission (trader perspective) |
| ═══ | ═══ | ═══ | ═══ |

Notes:
- Commission is only charged on profitable trades. On loss/zero: `Commission = 0`, `Net Profit = Gross Profit`, `ROI2 = ROI1`.
- The credit note (`traderCreditNote`) stores `metadata.grossProfit`, `metadata.commissionAmount`, `metadata.commissionRate`, `metadata.netProfit`.

---

## b) Investment — Calculation Schema (Investor view, pool mirror-trade)

Reminder on pool mechanics: Out of an investment pool, a mirror-trade buys as many
securities as possible under exchange-granularity constraints (e.g. lots of 10/100/1000).
The remainder after fees is the **Residual Credit**, which is credited back to each
investor proportionally to their share in the pool. Residual Credit is NOT part of
the ROI basis.

| +/− | Step | Formula | Meaning |
|:-:|---|---|---|
| + | Buy Amount (€) | Investor share of actually bought quantity × buyPrice | Investor buy value |
| + | Buy Fees (€) | Investor share of pool buy fees | Investor buy fees |
| ═══ | ═══ | ═══ | ═══ |
| **=** | **Total Buy Cost (€)** | `Buy Amount + Buy Fees` | **Actual invested capital (excl. residual)** |
| ═══ | ═══ | ═══ | ═══ |
| − | Residual Credit (€) | Investor share of pool residual | Separate credit — NOT part of the ROI basis |
| ═══ | ═══ | ═══ | ═══ |
| + | Sell Amount (€) | Investor share of pool sell | Investor sell value |
| − | Sell Fees (€) | Investor share of pool sell fees | Investor sell fees |
| ═══ | ═══ | ═══ | ═══ |
| **=** | **Net Sell Amount (€)** | `Sell Amount − Sell Fees` | Investor-share of net sale proceeds |
| ═══ | ═══ | ═══ | ═══ |
| − | Total Buy Cost (€) | `Buy Amount + Buy Fees` | Buy side total |
| ═══ | ═══ | ═══ | ═══ |
| **=** | **Gross Profit (€)** | `Net Sell Amount − Total Buy Cost` | Investment result before commission & taxes |
| ═══ | ═══ | ═══ | ═══ |
| **=** | **ROI1 (%)** | `Gross Profit / Total Buy Cost × 100` | Classical investor ROI (without commission) |
| ═══ | ═══ | ═══ | ═══ |
| − | Commission (€) | `Gross Profit × commissionRate` (only when Gross Profit > 0) | Investor pays commission to trader |
| ═══ | ═══ | ═══ | ═══ |
| **=** | **Net Profit (€)** | `Gross Profit − Commission` | Investor result after commission |
| ═══ | ═══ | ═══ | ═══ |
| **=** | **ROI2 (%)** | `Net Profit / Total Buy Cost × 100` | **Server-canonical `metadata.returnPercentage`** |
| ═══ | ═══ | ═══ | ═══ |

Notes:
- The investor UI column `Return (%)` and the `Return (%)` on the bill both show **ROI2**, derived from the same line items (`Net Profit / Total Buy Cost × 100`).
- The Commission Explanation Sheet additionally shows `Gross Profit (%)` = **ROI1** (derived from statement summary) for transparency.
- The Residual Credit is booked separately (`walletReceipt.receiptType = 'residualCredit'`) and does not enter the ROI basis.
- The App Service Charge is booked separately as a direct debit from the investor's cash-balance account (see Scope & Principles §4). It does NOT reduce Total Buy Cost or Net Profit in this schema.

---

## Backend field contract (unchanged)

`investorCollectionBill.metadata`:
- `ownershipPercentage` (number)
- `grossProfit` (number, €)
- `commission` (number, €)
- `netProfit` (number, €)
- `returnPercentage` (number, %) — **canonical ROI2**, required, DB-validated
- `commissionRate` (number)
- `buyLeg` (object: amount, quantity, fees, ...)
- `sellLeg` (object: amount, quantity, fees, ...)
- `taxBreakdown` (object, optional)

`traderCreditNote.metadata`:
- `grossProfit` (number, €)
- `commissionAmount` (number, €) — the commission the trader receives
- `commissionRate` (number)
- `netProfit` (number, €)
- `investorBreakdown` (array)
- `taxBreakdown` (object, optional)

These fields MUST remain stable; any consumer (bill/invoice PDF, admin report, CSR view, investor view) reads from them.

---

## Where the numbers are consumed (consistency map)

| Consumer | Field | Source | Value |
|---|---|---|---|
| `InvestorCollectionBill` PDF | `Gross Profit (€)`, `Commission (€)`, `Net Profit (€)`, `Total Buy Cost (€)` | Backend settlement → bill line items | — |
| Investor `CompletedInvestmentsTable` | `Gross Profit (€)` | `InvestorInvestmentStatementSummary.statementGrossProfit` (same aggregator that feeds the bill) | — |
| Investor `CompletedInvestmentsTable` | `Return (%)` | Derived: `(Gross Profit − Commission) / Total Buy Cost × 100` from the same statement summary | ROI2 |
| Investor `CommissionCalculationExplanationSheet` | `Gross Profit (%)` | Derived: `Gross Profit / Total Buy Cost × 100` | ROI1 |
| Investor `CommissionCalculationExplanationSheet` | `Return (%) after commission` | Derived: `(Gross Profit − Commission) / Total Buy Cost × 100` | ROI2 |
| Admin `AdminSummaryReportView` | `Return (%)` | `getSummaryReportInvestmentsPage` (ROI2 formula) | ROI2 |
| CSR `CSRInvestmentDetailSheet` | `Return (%)` | Backend metadata (ROI2) | ROI2 |
| CSR `CSRTradeDetailSheet` | `Return (%)` | Trade-level (trader perspective ROI1) | Trader-side ROI1 |

---

## Change log

- 2026-04-20: Initial version. Aligned terminology (Gross Profit, Net Profit, ROI1, ROI2), added Residual Credit as separate item in the Investment schema, and fixed admin summary report to use ROI2 (SSOT).
- 2026-04-20 (update): **Corrected SSOT direction.** QA identified that a stored
  `metadata.returnPercentage` (34,51 %) disagreed with the corresponding bill
  (Gross Profit 636,85 € / ROI ≈ 65,69 %). The Investor Collection Bill is the
  ground truth; ROI1/ROI2 are derived directly from its line items. The stored
  `metadata.returnPercentage` is kept as a denormalized analytics copy and must be
  reconciled against the bill, not the other way around.
- 2026-04-20 (update, rates clarified):
  - **Trader Commission** rate is **11 %** (configured via admin panel), applied to
    investor Gross Profit in the trade settlement (reduces Net Profit).
  - **App Service Charge** rate is **5 %** (configured via admin panel) of the gross
    investment amount, billed separately via direct debit from the investor
    cash-balance account at activation time — **not** a deduction from the investment
    amount before pool split. The account feature is disabled (no crypto trading), so
    the debit goes directly against the investor's cash balance; if the balance is
    insufficient, activation is blocked with an error. ADR-007 TBD.
- 2026-04-20 (update, backend SSOT fix):
  **Root-cause fix for the stored `metadata` disagreeing with the bill.** The
  backend `settleParticipation` in `accountingHelper/settlement.js` used to derive
  the investor's `profitShare / commission / netProfit` from
  `ownershipRatio × netTradingProfit` (trader-trade basis) while the Collection
  Bill PDF already showed per-investor mirror-trade legs (`buyLeg` / `sellLeg`).
  That is why `metadata.returnPercentage` stored 34,51 % on a bill that displayed
  ≈ 57 % post-commission and ≈ 64 % pre-commission.
  - Added pure helper `deriveMirrorTradeBasis(buyLeg, sellLeg, commissionRate)` in
    `accountingHelper/legs.js` returning `{ totalBuyCost, netSellAmount,
    grossProfit, commission, netProfit, returnPercentage }`.
  - `settleParticipation` now uses `deriveMirrorTradeBasis(...)` as SSOT for:
    - `PoolTradeParticipation.profitShare / commissionAmount / grossReturn`
      (`profitBasis = 'mirror'`).
    - Collection Bill `metadata.grossProfit / commission / netProfit /
      returnPercentage`.
    - `AccountStatement investment_return` amount (`capital + mirrorGrossProfit`).
    - `AccountStatement commission_debit` amount.
    - Trader `commission_credit` — sum of per-investor mirror-basis commissions
      (matches the "Gutschrift — Trader Commission Calculation" PDF).
  - When mirror legs cannot be computed (missing `tradeBuyPrice`/`tradeSellPrice`
    or zero `investmentCapital`) the settlement transparently falls back to the
    legacy proportional split and stamps `participation.profitBasis = 'proportional'`.
  - Regression fixture: `accountingHelper/__tests__/legs.mirrorBasis.test.js`.
  - Still TODO (tracked separately): (a) backfill existing
    `metadata.returnPercentage` values on old Collection Bills to the mirror-basis
    number; (b) implement lot-size granularity (10er / 100er / 1000er) in
    `computeInvestorBuyLeg` — source of that info still to be defined.
- 2026-04-23 (Phase A — fee-calculation parity):
  The backend mirror-trade helpers in `accountingHelper/legs.js` now apply the
  **Fremdkostenpauschale** (`isForeign = true`, flat € 1,50 per order) so that the
  server-derived `buyLeg / sellLeg` match the iOS `FeeCalculationService` line-by-line
  (buy-side matches exactly; sell-side has a ≤ € 1 residual because iOS today scales
  sell fees proportionally from the trader invoice while `legs.js` recomputes fresh —
  intentional minor asymmetry, closed in Phase B).
  - Touched: `accountingHelper/legs.js` (new `APPLY_FOREIGN_COSTS_PHASE_A` flag) and
    the regression fixture `accountingHelper/__tests__/legs.mirrorBasis.test.js`
    (now asserts 329 Stk / € 990,29 / € 7,50 fees / € 2,21 residual for mfischer and
    1.320 Stk / € 3.973,20 / € 25,34 fees / € 1,46 residual for smüller).
- 2026-04-23 (backfill — historical Collection Bills on Mirror-Basis SSOT):
  `backend/scripts/backfill-collection-bill-mirror-basis.js` (Node + MongoDB
  driver) reconstructs `buyLeg / sellLeg` via the shared `legs.js` helpers and
  rewrites `metadata.{grossProfit, commission, netProfit, returnPercentage,
  buyLeg, sellLeg, backfillSource, backfilledAt}` plus
  `PoolTradeParticipation.{profitShare, commissionAmount, grossReturn,
  profitBasis = 'mirror-backfill'}`. Dry-run first, then `APPLY=1`.
  - AccountStatement entries are **never** auto-rewritten; the script produces
    advisory diffs only. Real-money corrections require explicit Storno + Re-Book
    with their own Beleg.
  - Applied against fin1-server 2026-04-23: 2 test-account Collection Bills +
    2 Participations migrated. Advisories flagged on corresponding
    `investment_return` / `commission_debit` entries (delta ≈ 1.009 € / 248 €
    resp. 111 € / 27 €) — not applied, will be handled per-case.
- 2026-04-23 (Phase B data-model sketch — ADR-008):
  `Documentation/ADR-008-Per-Security-Fee-Profile.md` now carries a full
  Parse schema proposal (`FeeProfile` class with versioned tiers,
  `Security.defaultExchangeCode`, `Order.feeProfileId` +
  `feeProfileVersion` snapshot, `Configuration.fees.*` keys) and a staged
  migration plan. Implementation (Parse class migration + admin portal UI)
  still pending. Until then the Phase-A flat-rate flag keeps both sides
  aligned.
- 2026-04-23 (Phase C spec — ADR-009):
  `Documentation/ADR-009-iOS-Reads-Server-BuyLeg-SellLeg.md` finalizes the
  contract for iOS dropping its local recompute in favor of reading
  `metadata.buyLeg` / `metadata.sellLeg` directly. Gated behind the
  `features.collectionBillServerLegs` flag; depends on ADR-008 Phase B
  + full backfill + two consecutive weeks of `healthy=true` from
  `weekly-mirror-basis-drift-check.sh`.
- 2026-04-23 (ADR-007 Phase-2 backend stub):
  Cloud function `bookAppServiceCharge({ investmentId })` shipped in
  `backend/parse-server/cloud/functions/investment.js`. Idempotent, honours
  session-user or master-key, reuses the existing `afterSave Invoice`
  trigger for BankContra + AppLedger postings. Jest fixture file
  `investment.bookAppServiceCharge.test.js` (6 tests) locks the contract.
  iOS migration to call this function after the cash-balance debit still
  pending.
- 2026-04-23 (Investor UI Server-preferred ROI2 + drift warning):
  `CompletedInvestmentsTable` and `CommissionCalculationExplanationSheet`
  now prefer `metadata.returnPercentage` from the server (resolved via
  `ServerCalculatedReturnResolver.resolveCanonicalSummary`) and fall back
  to local derivation from the Collection-Bill statement summary only if
  the backend has not yet (or cannot) provide a canonical value. The info
  sheet additionally surfaces a small "local derivation would be X %"
  hint when the local and server values diverge by more than 0.05 pp —
  helpful during post-backfill transitions and as a CSR signal for bills
  that still need reconciliation. Backed by
  `CompletedInvestmentsViewModel.canonicalSummaries` /
  `InvestmentsViewModel.completedCanonicalSummaries`.
- 2026-04-23 (Mirror-basis drift monitoring):
  Added `backend/scripts/weekly-mirror-basis-drift-check.js` and the
  wrapper `scripts/run-mirror-basis-drift-check.sh`. A cron job on
  fin1-server runs it every Monday at 05:45 UTC (with a `@reboot
  --catchup` guard). It recomputes
  `deriveMirrorTradeBasis(buyLeg, sellLeg, commissionRate)` for each
  active `investorCollectionBill` document and compares to the stored
  `metadata.returnPercentage`; anything > 0.05 pp is logged as drift and
  surfaced via syslog + `logs/mirror-basis-drift.alert` for email pickup.
  First post-Phase-A run: `checkedDocuments=2, driftedDocuments=0,
  healthy=true`.
- 2026-04-23 (ADR-007 Phase-2 full-chain integration test):
  New Jest fixture `__tests__/investment.bookAppServiceCharge.integration.test.js`
  now runs the whole path end-to-end:
  `bookAppServiceCharge → Invoice.save() → afterSave Invoice →
  BankContraPosting[net|vat] + AppLedgerEntry[PLT-REV-PSC,
  PLT-TAX-VAT, PLT-CLR-GEN]`.
  The test locks down the three silent bugs we hand-patched in
  production on 2026-04-23: (1) `reference = "PSC-${batchId}"`, not
  `PSC-${invoice.id}`; (2) `investorId` must equal `invoice.userId`;
  (3) `investmentIds` must round-trip from the invoice.
  It also asserts the **double-entry invariant**
  (`Σ debit === Σ credit`) on the AppLedgerEntry rows. Suite
  totals: 108/108 locally, 100/100 on fin1-server (remote is
  missing the `trading.collectionBills.contract` + `admin/reports`
  fixtures — tracked separately).
- 2026-04-23 (ADR-007 Prod-Abnahme-Checkliste + Tech-Spec Sync):
  Neue Release-Checkliste für den Prod-Flip:
  `Documentation/RELEASE_CHECKLIST_2026-04-23_ADR-007_Service-Charge-Backend-Invoice.md`
  (inkl. Deploy-Schritte, Backend-Smokes, iOS-Soll, Rollback, **Admin-Portal-Anzeigename**). Hinweis: der Boolean ist aktuell **nicht** in
  `CRITICAL_PARAMETERS` — `requestConfigurationChange` wendet ihn **sofort** an (wie `walletFeatureEnabled`), es sei denn, er wird später in die Critical-Liste aufgenommen. `ADR-007` verweist darauf; `FIN1_APP_DOCS/03_TECHNISCHE_SPEZIFIKATION.md` und
  `ENGINEERING_GUIDE.md` wurden auf den aktuellen Primary-Path
  (`bookAppServiceCharge` + Flag + Bind-Mount-Deploy) synchronisiert.
- 2026-04-23 (ADR-007 `beforeSave Invoice` duplicate guard):
  `assertNoDuplicateServiceChargeBatch` (`invoiceDuplicateGuard.js`) wired
  from `beforeSave Invoice` so a second `service_charge` row with the same
  `batchId` is rejected (`DUPLICATE_VALUE`). Belt-and-suspenders against
  double BankContra/AppLedger if the iOS fail-safe `addInvoice` runs after
  the server already booked the batch. Jest: `invoiceDuplicateGuard.test.js`
  + integration harness updated to invoke `beforeSave`. iOS now treats this
  duplicate response as terminal success-equivalent (skip legacy fallback),
  and `ParseAPIClient+CloudFunctions` maps Parse 400 payloads to
  `NetworkError.badRequest(message)` so the duplicate reason is machine-readable.
- 2026-04-23 (ADR-007 Phase-2 client-migration flag flipped in Dev):
  `display.serviceChargeInvoiceFromBackend=true` set on fin1-server via a
  master-key `Configuration` update. `getConfig` now returns `true`, so the
  iOS client will route App-Service-Charge Invoice creation through the
  `bookAppServiceCharge` Cloud function on the next
  `fetchRemoteDisplayConfig()` cycle. Roundtrip verified against the live
  server: synthetic Investment → `bookAppServiceCharge` → 1 `Invoice` (server),
  2 `BankContraPosting` rows under `PSC-<batchId>` (not `PSC-<invoiceId>`;
  the 2026-04-23 trigger fix holds in prod), 3 `AppLedgerEntry` rows with
  `Σ debit === Σ credit`. Second call returns `skipped=true` with zero-delta
  across all three collections — the Parse `beforeSave`-idempotency index
  works against the real MongoDB store, not just Jest mocks. Test artefacts
  removed. Production flip is still pending and goes through the 4-eyes
  workflow (`requestConfigurationChange`).
- 2026-04-23 (Degrade-smoke for mirror-basis drift):
  Synthetic snapshot test against fin1-server to verify the
  `overall=degraded` rendering path end-to-end:
  `db.OpsHealthSnapshot.replaceOne` with `driftedDocuments=3,
  healthy=false, driftSamples=[…]` → `getMirrorBasisDriftStatus`
  returned `overall=degraded, reason="3 investorCollectionBill
  document(s) drifted from mirror-basis SSOT"` with the two
  synthetic samples in the payload. Rolled back by re-running
  `run-mirror-basis-drift-check.sh`; returned to
  `overall=healthy, driftedDocuments=0`. Confirms the admin
  section would surface the orange pill + sample rows correctly
  on a real drift event.
- 2026-04-23 (Admin-observability for the drift cron):
  The weekly mongosh script now also upserts the run summary into the
  `OpsHealthSnapshot` Mongo collection (`_id = 'mirror-basis-drift'`).
  New admin-only cloud function
  `getMirrorBasisDriftStatus` (`backend/parse-server/cloud/functions/admin/opsHealth.js`)
  reads that snapshot and derives a colour-coded `overall` (`healthy`,
  `degraded`, `down`, `unknown`) incorporating staleness thresholds
  (8 d → degraded, 14 d → down). Consumed by the new iOS
  `MirrorBasisDriftHealthSection` on `AdminDashboardView`, so admins
  see the reconciliation state without SSH-tailing
  `logs/mirror-basis-drift.log`. Jest fixture
  `admin/__tests__/opsHealth.test.js` (6 tests) locks the contract:
  unknown / healthy / degraded / down / admin-only / master-key.
  Remote smoke test 2026-04-23 returned
  `overall=healthy, checkedDocuments=2, driftedDocuments=0`
  after the first real snapshot.
