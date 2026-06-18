# Investor position amount — SSOT

**Scope:** One **position amount** per investment in UI tables and admin reports — **not** individual App Ledger / Account Statement lines.

**Related (GoB / bookings):** [`BOOKING_AND_BELEG_SSOT.md`](BOOKING_AND_BELEG_SSOT.md)  
**Related (return %):** [`RETURN_CALCULATION_SCHEMAS.md`](RETURN_CALCULATION_SCHEMAS.md)  
**Related (order cash, separate topic):** [`ORDER_CASH_AMOUNT_SSOT.md`](ORDER_CASH_AMOUNT_SSOT.md)

---

## Two layers (do not conflate)

| Layer | What it shows | SSOT |
|-------|----------------|------|
| **GoB / Ledger / Kontoauszug** | Many **booking legs** per investment lifecycle (`reserve`, deploy/split, settlement payout, …) | Amounts from **Beleg `metadata`** at booking time → `AppLedgerEntry` / `AccountStatement` |
| **Position display** | **One amount** per investment row (Reserved / Active / Completed tables, Summary Report) | Resolution chain below — must **reconcile** with ledger, not duplicate its line structure |

Ledger **RSV→PTR** at activation equals **`poolTradingAmount`**. Settlement uses Collection Bill **`totalBuyCost`**. Reservierung uses **`Investment.amount`** (nominal).

---

## Display resolution chain (SSOT)

Priority for **non-reserved** investments:

1. **Collection Bill `metadata.totalBuyCost`** (Σ over all bills for partial sells) — same as GoB after settlement  
2. **`Investment.poolTradingAmount`** — denormalized at activation (`escrowActivation.js`), aligned with RSV→PTR split  
3. **`Investment.amount`** — reserved nominal; also fallback when 1–2 missing  

**Reserved** (`status` or `reservationStatus` = `reserved`): always **`Investment.amount`** (nominal).

### Backend (Parse Cloud)

| Module | Role |
|--------|------|
| `backend/parse-server/cloud/utils/investmentDisplayAmount.js` | **SSOT** — `resolveInvestmentPositionAmount`, `bookedTotalBuyCostFromMetadata`, Mongo helpers |
| `…/reports/summaryReportInvestmentRows.js` | List rows: `mapInvestmentRow` + `loadCanonicalBillMetricsByInvestmentId` |
| `…/reports/summaryReportAggPipelines.js` | Overview KPI: `$lookup` Collection Bills → same position amount |

### iOS

| Symbol | Role |
|--------|------|
| `Investment.displayAmountForOpenPositions` | Active / Reserved open table (**Total buy** column) |
| `Investment.displayEffectiveInvestmentAmount(…)` | Completed table — Beleg canonical → statement → pool → nominal |
| `Investment.displayTraderUsername(using:)` | Trader username (stored → catalog → display name) |

---

## Consumers (consistency map)

| Consumer | Column / KPI | Resolver |
|----------|--------------|----------|
| iOS **Active Investments** | Total buy / amount | `displayAmountForOpenPositions` |
| iOS **Completed Investments** | InvestAmount | `displayEffectiveInvestmentAmount` |
| Admin **Summary Report → Investments** | Betrag | `getSummaryReportInvestmentsPage` → `resolveInvestmentPositionAmount` + bill metrics |
| Admin **Summary Report → Overview** | Investiertes Kapital (KPI) | `getSummaryReport` aggregate — `$lookup` + `investmentPositionAmountMongoExpression` |
| Admin **User Detail → InvestmentTable** | InvestAmount | `getUserDetails` → `usersDetailInvestor.js` |
| Admin **User Detail → KPI „Investiert“** | Summe | Positions-SSOT über alle Investments des Users |
| App Ledger / Kontoauszug | per entry | Beleg-driven legs — **not** this chain |

---

## Tests

- `backend/parse-server/cloud/utils/__tests__/investmentDisplayAmount.test.js`
- `backend/parse-server/cloud/functions/admin/reports/__tests__/summaryReportInvestmentAmount.test.js`
- `backend/parse-server/cloud/functions/admin/__tests__/usersDetailInvestor.test.js`

---

## Change log

- **2026-06-18:** User Detail InvestmentTable + KPI „Investiert“ an Positions-SSOT angebunden (`usersDetailInvestor.js`).
- **2026-06-18:** Initial doc. Unified Admin Summary Report list + Overview KPI with iOS position semantics; central module `investmentDisplayAmount.js`.
