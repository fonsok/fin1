# ADR-009: iOS renders Collection Bills exclusively from server-owned `metadata.buyLeg` / `metadata.sellLeg`

## Status
Proposed — depends on ADR-008 Phase B landing first.

## Date
2026-04-23

## Context

After ADR-006 (server-owned `metadata.returnPercentage`) and ADR-008 Phase A
(iOS and backend now both apply the same flat-rate fee constants,
0.5 % / 0.1 % / €1.50), the backend writes the full fee breakdown into every
`investorCollectionBill.metadata`:

```jsonc
metadata: {
  grossProfit, commission, netProfit, returnPercentage,
  buyLeg:  { quantity, amount, fees: { orderFee, exchangeFee, foreignCosts, totalFees }, residualAmount },
  sellLeg: { quantity, amount, fees: { orderFee, exchangeFee, foreignCosts, totalFees } }
}
```

Nonetheless `FIN1/Features/Investor/Services/InvestorCollectionBillCalculationService.swift`
**still recomputes** both legs locally on every render so the PDF generator
can lay out the line items. That dual-source setup has three downsides:

1. **Two code paths to keep in sync.** Any rate change today has to land in
   both languages (Swift + JS) with matching rounding behaviour. Phase-A
   regression tests in `legs.mirrorBasis.test.js` guard this, but each
   change still needs two reviews and two deploys.
2. **Rendering drift is possible.** The iOS recompute uses the iOS `Order`
   entity (which stores `price` in EUR), while the backend uses the same
   fields in `Trade`/`Order` from Parse. Subtle differences (e.g. residual
   rounding when quantity steps force a truncation) have already caused
   ≤ 1 € drift between PDF and bill metadata in the past.
3. **Phase B cannot land cleanly.** Once per-venue fee profiles (ADR-008)
   ship, iOS would also need to resolve `(order, security) → feeProfile`
   client-side. That resolver is server-authoritative by design, so
   duplicating it client-side is a regression on the SSOT goal.

## Decision

Once ADR-008 Phase B has shipped and at least one settlement cycle has
produced bills with the new feeProfile-driven `metadata`:

1. **iOS stops recomputing legs.**
   `InvestorCollectionBillCalculationService` becomes a pure reader of
   `document.metadata.buyLeg` / `document.metadata.sellLeg`. No Swift-side
   `calculateOrderFees`, no residual re-derivation, no quantity-step
   enforcement — those are facts from the server.
2. **Fallback is "pending", not "recompute".** A bill that lacks either leg
   renders the same `pending` state the client already uses for
   `metadata.returnPercentage` (ADR-006). The CSR / investor then knows the
   bill is waiting on a backend backfill rather than seeing a plausible-but-
   divergent value.
3. **PDF layout reads `metadata` directly.** The PDF layout code in
   `FIN1/Features/Investor/Views/Collection/InvestorCollectionBill*.swift`
   takes `buyLeg` / `sellLeg` as its input model (typed Swift struct that
   mirrors the JS object), and is no longer aware of `Trade` / `Order` /
   fees.
4. **Feature flag for rollout.**
   `features.collectionBillServerLegs` (default `false` during rollout) gates
   step 1. When flipped on, any bill without server-side legs is treated per
   step 2. Post-flip, the local recompute code is deleted in the next
   cleanup commit — with a regression test that asserts no remaining Swift
   caller of the legacy recompute helpers.

## Pre-conditions

- **ADR-008 Phase B shipped in production.** Per-venue fee profiles are
  live; new `Order` rows carry `feeProfileId` + `feeProfileVersion`; admin
  portal has at least the venues used by current securities (XETRA, TGT, FRA,
  LSE, NYSE) configured.
- **Backfill complete.** Run `backend/scripts/backfill-collection-bill-mirror-basis.js`
  over all historical `investorCollectionBill` documents with
  `APPLY=1`. Reconciliation cron (ADR-006 / this repo's
  `run-mirror-basis-drift-check.sh`) reports `healthy=true` for at least
  two consecutive weeks.
- **iOS DTO lock-in.** Define a Swift `ServerFeeBreakdown` struct that 1:1
  mirrors the server `fees` shape and verify parity via a fixture-based
  decode test.

## Migration plan

1. Introduce `features.collectionBillServerLegs = false` in `Configuration`.
2. In `InvestorCollectionBillCalculationService`, add a `.serverFirst` mode
   that, when the feature flag is on, only reads from `metadata.buyLeg` /
   `metadata.sellLeg`. Keep the legacy recompute path for the flag-off case.
3. Enable the flag in staging for two settlement cycles; compare PDF
   renderings pre/post via snapshot tests
   (`FIN1Tests/UITests/CollectionBillRenderingTests.swift`, new file).
4. Flip the flag in production. Keep the legacy path for one release as an
   escape hatch.
5. Delete the legacy recompute path. Add a SwiftLint / unit-test guard that
   fails the build if `calculateOrderFees(for: order, isForeign: …)` has
   callers outside the `Trader` order-creation flow (which is a different
   concern and stays untouched).

## Contract (post-flip)

- Any bill displayed to an investor MUST carry `metadata.buyLeg` and
  `metadata.sellLeg`. Backend enforces this at write time (already true
  since Phase A).
- Legacy bills (pre-backfill) show `pending` for the affected line items.
  Backoffice runs the backfill; the bill returns to a rendered state on the
  next refresh.
- Rate-schedule changes post-flip do NOT retro-edit bills. The
  `feeProfileVersion` snapshot in `Order` (ADR-008) guarantees historical
  reproducibility.

## Alternatives Considered

1. **Jump straight from Phase A to Phase C**, skipping Phase B's per-venue
   profile. Rejected: the flat-rate simplification is the whole reason
   client recompute is currently easy — once we break that lock-step (which
   ADR-008 Phase B explicitly does), the only sane plan is to also drop the
   client recompute.
2. **Ship Phase C behind a per-investor override**, so early-adopters render
   from the server first. Rejected for MVP: the flag-based cutover is
   simpler and avoids long-tail double-rendering bugs.
3. **Keep client recompute as a verifier** (render server → compare to local
   → alert on drift). Accepted as a **staging-only QA hook**, not a
   production path — a drift in production must alert via the cron
   reconciliation, not be silently absorbed client-side.

## Consequences

- iOS investor bundle loses the fee-calculation dependency on `Trade` /
  `Order` models for bill rendering (still needed elsewhere, e.g. trader
  order creation).
- Any future fee-schedule change ships purely via `FeeProfile` rows in the
  admin portal — zero Swift code changes, zero app store release.
- The PDF pipeline becomes trivially testable with JSON fixtures; no Parse
  mock plumbing needed for layout tests.
- Completes the ADR-006 SSOT story for all investor-facing financial
  numbers: `returnPercentage`, `grossProfit`, `commission`, `netProfit`,
  `buyLeg`, `sellLeg`. After this ADR, the client derives **nothing**
  money-related.

## Out of Scope

- Trader-side order creation (still computes expected fees client-side for
  the pre-order preview — that's a UX affordance, not an accounting source
  of truth).
- Admin reports (already server-owned via the reports Cloud functions).
- Non-EUR settlement (covered by future FX ADR if/when relevant).

## Related

- ADR-012 — Teil-Sell-Kennzahlen (iOS), Finance-Consistency-Smoke, Admin-System-Health (`Documentation/ADR-012-Partial-Sell-Metrics-Finance-Smoke-And-Ops.md`) — ergänzt die SSOT-Linie für **Investment**-Felder und Betriebs-QA
- ADR-006 — Server-Owned Return Percentage Contract
- ADR-007 — App Service Charge Direct-Debit (Cash Balance)
- ADR-008 — Per-Security / Per-Exchange Fee Profile
- `Documentation/RETURN_CALCULATION_SCHEMAS.md` — schemas, Phase A log,
  backfill log
- `backend/parse-server/cloud/utils/accountingHelper/legs.js`
- `backend/scripts/backfill-collection-bill-mirror-basis.js`
- `backend/scripts/weekly-mirror-basis-drift-check.js`
- `FIN1/Features/Investor/Services/InvestorCollectionBillCalculationService.swift`
- `FIN1/Features/Investor/Services/ServerCalculatedReturnResolver.swift`
