# ADR-008: Per-Security / Per-Exchange Fee Profile (Phase B + C)

## Status
Proposed — data model finalized 2026-04-23; Parse-class migration and admin
portal UI still pending.

## Date
2026-04-20 (initial) · 2026-04-23 (data-model sketch)

## Context
The 2026-04-20 Mirror-Basis refactor (ADR-006 follow-up; see
`Documentation/RETURN_CALCULATION_SCHEMAS.md` change log entries for that day)
aligned backend `legs.js` with the iOS `FeeCalculationService` on a flat-rate
fee simplification:

- Order fee: 0.5 % of order amount, clamped to [5 €, 50 €]
- Exchange fee: 0.1 % of order amount, clamped to [1 €, 20 €]
- Foreign costs: **fixed 1.50 € flat** per leg

That flat-rate model is a deliberate Phase A compromise. The real-world
specification the user confirmed on 2026-04-20 is:

> "Die Höhe der Fremdkosten ist abhängig vom jeweiligen Börsenplatz an dem das
> Wertpapier gehandelt wird und von der Höhe des Ordervolumens."

— foreign costs (and potentially exchange fees) depend on:

1. the security's trading venue (`Börsenplatz`, e.g. XETRA, Tradegate, Frankfurt,
   LSE, NYSE, …);
2. the order volume tier (€ 0–5.000 / € 5.000–25.000 / € 25.000+ / …).

Today the iOS `InvestorCollectionBillCalculationService` recomputes Buy fees
from the flat rates **but** scales Sell fees proportionally from the trader's
actual Sell invoice — an asymmetry that adds a ≤ 1 € / bill drift between
backend `metadata.sellLeg` and the iOS-rendered PDF. A proper per-venue fee
profile would eliminate the asymmetry by giving both sides the same
deterministic input.

## Decision

### Phase B — Data model: per-security / per-exchange fee profile

Introduce a `feeProfile` entity that keys off the `Security`/`Order`:

- `feeProfile.exchangeCode` (e.g. `XETRA`, `TGT`, `FRA`, `LSE`, `NYSE`)
- `feeProfile.orderFeeTiers: [{ minAmount, maxAmount, rate, min, max }]`
- `feeProfile.exchangeFeeTiers: [{ minAmount, maxAmount, rate, min, max }]`
- `feeProfile.foreignCostsTiers: [{ minAmount, maxAmount, fixed }]`
- `feeProfile.version`, `feeProfile.validFrom`, `feeProfile.validTo`

Admin-portal configurable (new section under `Configuration → Fees`).

Both the backend (`backend/parse-server/cloud/utils/accountingHelper/legs.js`)
and the iOS `FeeCalculationService` read from the same profile (via Parse
Config shipped to the client). They MUST produce identical fee numbers for
identical `(orderAmount, exchangeCode)` inputs — enforced by cross-language
regression tests (fixtures in `backend/parse-server/cloud/utils/accountingHelper/__tests__/`
and `FIN1Tests/Unit/Services/FeeCalculationServiceTests.swift`).

### Phase C — iOS reads `metadata.buyLeg / sellLeg` exclusively

Once Phase B has rolled out and at least one full settlement cycle has produced
Collection Bills with the new feeProfile-driven `metadata`:

1. Remove the local recompute fallback in
   `FIN1/Features/Investor/Services/InvestorCollectionBillCalculationService.swift`
   — the client ONLY renders what the backend stored in `metadata.buyLeg` /
   `metadata.sellLeg`.
2. Any bill lacking `metadata.buyLeg` / `metadata.sellLeg` displays
   `pending` (same contract as ADR-006 for `metadata.returnPercentage`).
3. Backfill any legacy bills via
   `backend/scripts/backfill-collection-bill-mirror-basis.js` before flipping
   the feature flag.

## Contract (forward-looking)

- `Document.metadata.buyLeg` / `sellLeg` — `{ quantity, amount, fees: { orderFee,
  exchangeFee, foreignCosts, totalFees }, residualAmount? }`, required on active
  `investorCollectionBill` documents.
- `Order.feeProfileVersion` — snapshot of the feeProfile at the time the order
  was placed (so historical bills remain reproducible after fee-schedule
  changes).

## Data-Model Sketch (Parse classes)

### `FeeProfile` (new Parse class)
| Field | Type | Notes |
|-------|------|-------|
| `objectId` | String | Parse-assigned |
| `exchangeCode` | String | e.g. `XETRA`, `TGT`, `FRA`, `LSE`, `NYSE` — unique together with `version` |
| `label` | String | human-readable, shown in admin portal (`XETRA – Standard 2026`) |
| `version` | Integer | monotonically increasing per `exchangeCode`; new rows are never updated — a rate change creates a new `version` row |
| `validFrom` | Date | inclusive |
| `validTo` | Date? | null = open-ended |
| `orderFeeTiers` | Array<Tier> | `[{ minAmount, maxAmount, rate, min, max }]` – tiers are inclusive on `minAmount`, exclusive on `maxAmount`; `maxAmount == null` = open top |
| `exchangeFeeTiers` | Array<Tier> | same shape |
| `foreignCostsTiers` | Array<{ minAmount, maxAmount, fixed }> | fixed € per leg; empty array ⇒ no foreign costs at this venue |
| `currency` | String | default `"EUR"` |
| `createdBy` | Pointer<`_User`> | admin audit |
| `notes` | String? | admin-only, free-text audit trail for rate updates |

`FeeProfile` documents are immutable once referenced by any `Order` — edits
create a new `version` row; the admin UI exposes "clone + edit" only, no
in-place mutation.

### `Security` (extend existing class)
| Field (new) | Type | Notes |
|-------------|------|-------|
| `defaultExchangeCode` | String | used when the order itself doesn't specify a venue (fallback — should rarely fire once the UI passes venue explicitly) |
| `feeProfilePointer` | Pointer<`FeeProfile`> | optional override for securities with non-standard fee arrangements (e.g. in-house issuances, Fonds) |

### `Order` (extend existing class)
| Field (new) | Type | Notes |
|-------------|------|-------|
| `exchangeCode` | String | the venue actually used for this order (filled at order creation time) |
| `feeProfileId` | String | objectId of the `FeeProfile` row resolved for `(exchangeCode, createdAt)` — snapshot, never rewritten |
| `feeProfileVersion` | Integer | duplicated from `FeeProfile.version` for audit without joins |

### `Configuration` (existing class) — keys added
| Key | Type | Notes |
|-----|------|-------|
| `fees.defaultExchangeCode` | String | fallback for orders missing `exchangeCode` |
| `fees.legacyFlatProfileId` | String | objectId of the "flat-rate" FeeProfile that encodes the Phase-A rates (0.5 %/0.1 %/1.50 €) — assigned to historical Orders by the migration script so that reruns of `legs.js` on old bills still match the PDFs |

### Resolution algorithm (both legs.js + FeeCalculationService)

```
function resolveFeeProfile(order, security, config, now = Date.now()):
  exchangeCode  = order.exchangeCode
               ?? security.defaultExchangeCode
               ?? config.fees.defaultExchangeCode     // Xetra by default

  // 1. Direct override on the security wins (issuer-specific rates)
  if security.feeProfilePointer is set: return it

  // 2. Otherwise find the active profile for (exchangeCode, now)
  query FeeProfile where exchangeCode == exchangeCode
                     AND validFrom <= now
                     AND (validTo == null OR validTo > now)
    sort by version desc
    limit 1
  → return the match, or throw `FEE_PROFILE_MISSING` (never silently use flat-rate)
```

The resolved `feeProfileId` + `feeProfileVersion` are **snapshotted onto the
Order at creation time**. Reruns (`backfill-collection-bill-mirror-basis.js`,
backoffice investigations) re-read the snapshot instead of re-resolving, so
rate-schedule changes after the fact don't retroactively change historical
bills.

### Client-side delivery

Fee profiles are shipped to iOS via a new `getActiveFeeProfiles` Cloud
function (cacheable; TTL ≈ 1 h). `FeeCalculationService` drops its hard-coded
0.5 % / 0.1 % / 1.50 € constants and takes a resolved `FeeProfile` as
input. For orders already placed it uses
`order.feeProfileId + order.feeProfileVersion` to look up the exact snapshot
used server-side.

### Migration plan

1. Create `FeeProfile.legacyFlat` row (orderFee 0.5 %[5,50], exchangeFee
   0.1 %[1,20], foreignCosts fixed 1.50) with `exchangeCode='*'` and
   `version=1`, `validFrom=<project start>`, `validTo=<switch-over date>`.
2. Backfill all existing `Order` rows with
   `feeProfileId = legacyFlat.objectId`, `feeProfileVersion = 1`,
   `exchangeCode = security.defaultExchangeCode ?? 'XETRA'` — idempotent
   script, separate from the mirror-basis backfill.
3. Create real per-venue `FeeProfile` rows via admin portal (XETRA, TGT,
   FRA, LSE, NYSE to start).
4. Flip Configuration key: new orders resolve to the real profile, historical
   orders still resolve to the snapshot. Cross-language regression tests (iOS
   ↔ legs.js) prove parity before any PDF-facing change ships.

## Alternatives Considered

1. **Keep flat-rate indefinitely.** Rejected: overcharges cheap venues (Tradegate
   zero-foreign) and undercharges exotic venues; diverges from actual broker
   invoices; risk of investor complaint.
2. **Client-only re-compute (status quo).** Rejected: violates server-owned
   SSOT (ADR-006), creates rendering drift, blocks Phase C.
3. **Backend-only, client blind.** Rejected for now: iOS still needs enough
   fee context to render the PDF if Phase C is delayed.

## Consequences

- New admin-portal screen for fee profiles.
- Schema migration for `Security` → `feeProfileId` and `Order` →
  `feeProfileVersion`.
- iOS config plumbing to read fee profiles from Parse Config.
- Phase B shipping unblocks Phase C, which completes the ADR-006 SSOT story
  for bills.

## Out of Scope

- Tax/VAT schedule changes (covered by ADR-005).
- Commission rate (configured per admin panel, stays orthogonal).
- Residual credit rounding policy.

## Related

- ADR-006 — Server-Owned Return Percentage Contract
- ADR-007 — App Service Charge Direct-Debit (Cash Balance)
- ADR-009 — iOS reads `metadata.buyLeg/sellLeg` exclusively (Phase C, depends on this ADR)
- ADR-012 — Teil-Sell-Kennzahlen (iOS), Finance-Smoke, System-Health (`Documentation/ADR-012-Partial-Sell-Metrics-Finance-Smoke-And-Ops.md`)
- `Documentation/RETURN_CALCULATION_SCHEMAS.md` — current schemas + Phase A log
- `backend/parse-server/cloud/utils/accountingHelper/legs.js`
- `FIN1/Shared/Services/FeeCalculationService.swift`
- `FIN1/Features/Investor/Services/InvestorCollectionBillCalculationService.swift`
